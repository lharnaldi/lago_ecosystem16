library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axis_lfsr is
  generic (
            HAS_TREADY      : boolean := FALSE;
            AXIS_TDATA_WIDTH: natural := 64
          );
  port (
         -- System signals
         aclk          : in std_logic;
         aresetn       : in std_logic;

         -- Master side
         m_axis_tready : in std_logic;
         m_axis_tvalid : out std_logic;
         m_axis_tdata  : out std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0)
       );
end axis_lfsr;

architecture rtl of axis_lfsr is
  signal int_lfsr_reg, int_lfsr_next : std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
  signal int_enbl_reg, int_enbl_next : std_logic;
  signal tmp_sig                     : std_logic;

begin

  process(aclk)
  begin
    if rising_edge(aclk) then 
      if aresetn = '0' then
        int_lfsr_reg <= std_logic_vector(to_unsigned(16#5#, AXIS_TDATA_WIDTH));
        int_enbl_reg <= '0';
      else 
        int_lfsr_reg <= int_lfsr_next;
        int_enbl_reg <= int_enbl_next;
      end if;
      end if;
    end process;
    
    tmp_sig <= int_lfsr_reg(AXIS_TDATA_WIDTH-2) xnor int_lfsr_reg(AXIS_TDATA_WIDTH-3);

    WITH_TREADY: if (HAS_TREADY) generate
      int_lfsr_next <= int_lfsr_reg(AXIS_TDATA_WIDTH-2 downto 0) & tmp_sig when (int_enbl_reg = '1' and m_axis_tready = '1') else 
                       int_lfsr_reg;
      int_enbl_next <= '1' when (int_enbl_reg = '0') else 
                       int_enbl_reg;
    end generate;
    NO_TREADY: if (not HAS_TREADY) generate
      int_lfsr_next <= int_lfsr_reg(AXIS_TDATA_WIDTH-2 downto 0) & tmp_sig when (int_enbl_reg = '1') else 
                       int_lfsr_reg;
      int_enbl_next <= '1' when (int_enbl_reg = '0') else 
                       int_enbl_reg;
    end generate;

  m_axis_tdata <= int_lfsr_reg;
  m_axis_tvalid <= int_enbl_reg;
end rtl;
