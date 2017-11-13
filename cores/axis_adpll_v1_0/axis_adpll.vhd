library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity adpll is
generic (
  AXIS_TDATA_WIDTH: natural := 32;
  ADC_DATA_WIDTH  : natural := 14
);
port(
  aclk         : in std_logic;
  aresetn      : in std_logic;
  kp_i         : in std_logic_vector(32-1 downto 0); --proportional gain 
  ki_i         : in std_logic_vector(32-1 downto 0); --integral gain

  gen_en_i     : in std_logic; 
  freq_i       : in std_logic_vector(32-1 downto 0); --frequency value for generator
  ref_i        : in std_logic; 
--  phase_I    : out std_logic_vector (14-1 downto 0);
--  phase_Q    : out std_logic_vector (14-1 downto 0);
  locked_o     : out std_logic;
--  sin_o        : out std_logic_vector(14-1 downto 0);
--  cos_o        : out std_logic_vector(14-1 downto 0);

  -- Master side
  m_axis_tdata : out std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
  m_axis_tvalid: out std_logic

);
end adpll;

architecture rtl of adpll is

--constant C_GAIN: std_logic_vector(32-1 downto 0):= std_logic_vector(to_unsigned(2097152, 32)); --"00000000001000000000000000000000"; 8192.00
--constant I_GAIN: std_logic_vector(32-1 downto 0):=std_logic_vector(to_unsigned(32,32));
constant PADDING_WIDTH : natural := AXIS_TDATA_WIDTH/2 - ADC_DATA_WIDTH;

--input registers for loop filter parameters
signal kp_reg, kp_next : std_logic_vector(32-1 downto 0);
signal ki_reg, ki_next : std_logic_vector(32-1 downto 0);

--PSD realted signals
signal reset: std_logic := '0';
signal comp_up_reg, comp_up_next : std_logic := '0';
signal comp_dn_reg, comp_dn_next : std_logic := '0';

--Loop filter related signals
signal pos_gain_reg, pos_gain_next : std_logic_vector(32-1 downto 0);
signal neg_gain_reg, neg_gain_next : std_logic_vector(32-1 downto 0);
signal dds_fbk_reg, dds_fbk_next   : std_logic_vector(32-1 downto 0);
signal dds_fbk                     : std_logic_vector(32-1 downto 0);

--DDS related signals
signal phase_acc_reg, phase_acc_next: std_logic_vector(50-1 downto 0);
signal phase_step: std_logic_vector(50-1 downto 0) := (others => '0');
signal dds_sync  : std_logic;

signal lut_addr  : std_logic_vector(14-1 downto 0);
signal sine      : std_logic_vector(14-1 downto 0);
signal cosine    : std_logic_vector(14-1 downto 0);

signal gen_s     : std_logic;
signal ref_s     : std_logic;

begin

  --Master side
  m_axis_tvalid <= '1';
  --padding to m_axis_tdata size
  m_axis_tdata <= ((PADDING_WIDTH-1) downto 0 => sine(ADC_DATA_WIDTH-1)) & sine & ((PADDING_WIDTH-1) downto 0 => cosine(ADC_DATA_WIDTH-1)) & cosine;
  
  -- mux the input reference
  ref_s <= gen_s when gen_en_i = '1' else
           ref_i;
  
  --register the input loop filter parameters
  process(aclk)
  begin
  if rising_edge(aclk) then
    if (aresetn = '0') then
      --convenient initialization
      kp_reg <= std_logic_vector(to_unsigned(2097152, 32));
      ki_reg <= std_logic_vector(to_unsigned(32,32));
    else
      kp_reg <= kp_next;
      ki_reg <= ki_next;
    end if;
  end if;
  end process;
  
  kp_next <= kp_i;
  ki_next <= ki_i;
  
  reset   <= comp_up_reg and comp_dn_reg;
  
  --PFD phase comparator flip flops
  process(ref_s, reset)
  begin
   if (reset = '1') then
    comp_up_reg <= '0';
   elsif rising_edge(ref_s)  then
    comp_up_reg <= comp_up_next;
  end if;
  end process;
  
  comp_up_next <= '1';
  
  process(dds_sync, reset)
  begin
   if (reset = '1') then
    comp_dn_reg <= '0';
   elsif rising_edge(dds_sync) then
    comp_dn_reg <= comp_dn_next;
  end if;
  end process;
  
  comp_dn_next <= '1';
  
  -- PI loop filter
  process(aclk)
  begin
   if rising_edge(aclk) then
     if (aresetn = '0') then
       dds_fbk_reg <= (others => '0');
       pos_gain_reg <= (others => '0');
       neg_gain_reg <= (others => '0');
       phase_acc_reg <= (others => '0');
     else
       dds_fbk_reg <= dds_fbk_next;
       pos_gain_reg <= pos_gain_next;
       neg_gain_reg <= neg_gain_next;
       phase_acc_reg <= phase_acc_next;
     end if;
   end if;
  end process;
  
   dds_fbk_next <= std_logic_vector(unsigned(dds_fbk_reg)-unsigned(ki_reg)) when ((comp_dn_reg = '1') and (comp_up_reg = '0')) else
                  std_logic_vector(unsigned(dds_fbk_reg)+unsigned(ki_reg)) when ((comp_up_reg = '1') and (comp_dn_reg = '0')) else 
                  dds_fbk_reg;
  
   pos_gain_next <= kp_reg when (comp_up_reg = '1') else
                   (others =>'0') when (comp_dn_reg = '1') else
                   (others =>'0');
  
   neg_gain_next <= kp_reg when (comp_dn_reg = '1') else
                    (others =>'0') when (comp_up_reg = '1') else
                    (others =>'0');
  
   dds_fbk <= std_logic_vector(unsigned(dds_fbk_reg) + unsigned(pos_gain_reg) - unsigned(neg_gain_reg) + 64);
   
   --DDS signal generator
   phase_step <= std_logic_vector(to_unsigned(35184,18) * unsigned(dds_fbk));
  
   phase_acc_next <= std_logic_vector(unsigned(phase_acc_reg) + unsigned(phase_step));
  
   dds_sync <= not(phase_acc_reg(50-1));
  
  -- phase_I <= phase_acc_reg(50-1 downto 36);
  -- phase_Q <= std_logic_vector(unsigned(phase_acc_reg(50-1 downto 36)) + to_unsigned(4095, 12));
  
   lut_addr <= phase_acc_reg(50-1 downto 36);
   
   lut: entity work.sincos_lut_14 
     port map( 
       clk_i   => aclk,
       addr_i  => lut_addr,
       sin     => sine,
       cos     => cosine
     );
   
   --Locked state detector
   lock_indicator: entity work.lock_det
     port map(
       aclk     => aclk,
       aresetn  => aresetn,
       ref_i    => ref_s,
       dds_sync_i => dds_sync,
       locked_o => locked_o
  );
  
   --clock generator
   clock_gen: entity work.clk_gen
     port map(
       aclk   => aclk,
       freq_i => freq_i,
       div_o  => gen_s
  );

end rtl;

