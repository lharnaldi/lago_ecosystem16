library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity zero_cross_det is
generic (
  HYST_CONST      : natural := 2048; --"00100000000000"
  AXIS_TDATA_WIDTH: natural := 32
);
port (
  aclk    : in std_logic;
  aresetn : in std_logic;

  det_a_o : out std_logic;
  det_b_o : out std_logic;

 -- Slave side
  s_axis_tready: out std_logic;
  s_axis_tdata : in std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0)
);
end zero_cross_det;

architecture rtl of zero_cross_det is

signal sig_a_reg, sig_a_next: std_logic_vector(AXIS_TDATA_WIDTH/2-1 downto 0);
signal sig_b_reg, sig_b_next: std_logic_vector(AXIS_TDATA_WIDTH/2-1 downto 0);
signal det_a_o_reg, det_a_o_next: std_logic;
signal det_b_o_reg, det_b_o_next: std_logic;
signal hyst_a_low_reg, hyst_a_low_next  : std_logic;
signal hyst_a_high_reg, hyst_a_high_next : std_logic;
signal hyst_b_low_reg, hyst_b_low_next  : std_logic;
signal hyst_b_high_reg, hyst_b_high_next : std_logic;

begin

  process(aclk)
  begin
  if rising_edge(aclk) then
    if aresetn = '0' then
      sig_a_reg <= (others => '0');
      det_a_o_reg <= '0';
      hyst_a_low_reg <= '0';
      hyst_a_high_reg <= '0';

      sig_b_reg <= (others => '0');
      det_b_o_reg <= '0';
      hyst_b_low_reg <= '0';
      hyst_b_high_reg <= '0';
    else
      sig_a_reg <= sig_a_next;
      det_a_o_reg <= det_a_o_next;
      hyst_a_low_reg <= hyst_a_low_next;
      hyst_a_high_reg <= hyst_a_high_next;

      sig_b_reg <= sig_b_next;
      det_b_o_reg <= det_b_o_next;
      hyst_b_low_reg <= hyst_b_low_next;
      hyst_b_high_reg <= hyst_b_high_next;
    end if;
  end if;
  end process;

  --Next state logic
  sig_a_next <= s_axis_tdata(AXIS_TDATA_WIDTH/2-1 downto 0);
  
  det_a_o_next <= '1' when (sig_a_reg(sig_a_reg'left) = '1' and sig_a_next(sig_a_next'left) = '0' and hyst_a_low_reg = '1') else
                '0' when (sig_a_reg(sig_a_reg'left) = '0' and sig_a_next(sig_a_next'left) = '1' and hyst_a_high_reg = '1') else
                det_a_o_reg;
  
  hyst_a_low_next  <= '1' when (signed(sig_a_next) < (to_signed(-HYST_CONST, AXIS_TDATA_WIDTH/2))) else 
                    '0' when (sig_a_reg(sig_a_reg'left) = '1' and sig_a_next(sig_a_next'left) = '0' and hyst_a_low_reg = '1') else
                    hyst_a_low_reg;
  
  hyst_a_high_next <= '1' when (signed(sig_a_next) > (to_signed(HYST_CONST, AXIS_TDATA_WIDTH/2))) else
                    '0' when (sig_a_reg(sig_a_reg'left) = '0' and sig_a_next(sig_a_next'left) = '1' and hyst_a_high_reg = '1') else
                    hyst_a_high_reg;
  
  det_a_o <= det_a_o_reg;
  
  sig_b_next <= s_axis_tdata(AXIS_TDATA_WIDTH-1 downto AXIS_TDATA_WIDTH/2);
  
  det_b_o_next <= '1' when (sig_b_reg(sig_b_reg'left) = '1' and sig_b_next(sig_b_next'left) = '0' and hyst_b_low_reg = '1') else
                '0' when (sig_b_reg(sig_b_reg'left) = '0' and sig_b_next(sig_b_next'left) = '1' and hyst_b_high_reg = '1') else
                det_b_o_reg;
  
  hyst_b_low_next  <= '1' when (signed(sig_b_next) < (to_signed(-HYST_CONST, AXIS_TDATA_WIDTH/2))) else 
                    '0' when (sig_b_reg(sig_b_reg'left) = '1' and sig_b_next(sig_b_next'left) = '0' and hyst_b_low_reg = '1') else
                    hyst_b_low_reg;
  
  hyst_b_high_next <= '1' when (signed(sig_b_next) > (to_signed(HYST_CONST, AXIS_TDATA_WIDTH/2))) else
                    '0' when (sig_b_reg(sig_b_reg'left) = '0' and sig_b_next(sig_b_next'left) = '1' and hyst_b_high_reg = '1') else
                    hyst_b_high_reg;
  
  det_b_o <= det_b_o_reg;


  s_axis_tready <= '1';

end rtl;
