library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axis_phase_generator is
generic (
  AXIS_TDATA_WIDTH : natural := 32;
  PHASE_WIDTH      : natural := 30
);
port (
  -- System signals
  aclk               : in std_logic;
  aresetn            : in std_logic;

  cfg_data           : in std_logic_vector(PHASE_WIDTH-1 downto 0);     
                
  -- Master side
  m_axis_tready      : in std_logic;                        
  m_axis_tdata       : out std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0); 
  m_axis_tvalid      : out std_logic                        
);
end axis_phase_generator;

architecture rtl of axis_phase_generator is
  signal int_cntr_reg, int_cntr_next : std_logic_vector(PHASE_WIDTH-1 downto 0);
  signal int_enbl_reg, int_enbl_next : std_logic; 

begin

  process(aclk)
  begin
    if (rising_edge(aclk)) then
      if (aresetn = '0') then
        int_cntr_reg <= (others => '0');
        int_enbl_reg <= '0';
      else
        int_cntr_reg <= int_cntr_next;
        int_enbl_reg <= int_enbl_next;
      end if;
    end if;
  end process;

  -- next state logic
  int_cntr_next <= std_logic_vector(unsigned(int_cntr_reg)+unsigned(cfg_data))
                   when (int_enbl_reg /= '0' and m_axis_tready = '1') else
                   int_cntr_reg;
  int_enbl_next <= '1' when (int_enbl_reg = '0') else
                   int_enbl_reg;

  --m_axis_tdata  <= ((AXIS_TDATA_WIDTH-PHASE_WIDTH-1) downto 0  => int_cntr_reg(PHASE_WIDTH-1)) & int_cntr_reg;
  m_axis_tdata  <= std_logic_vector(resize(unsigned(int_cntr_reg), m_axis_tdata'length));
  m_axis_tvalid <= int_enbl_reg;
end rtl;

