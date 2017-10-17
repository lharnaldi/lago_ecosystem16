library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axis_bram_writer is
  generic (
  BRAM_ADDR_WIDTH   : natural := 10;
  BRAM_DATA_WIDTH   : natural := 32;
  AXIS_TDATA_WIDTH  : natural := 32
  );
  port (
  -- System signals
  aclk             : in std_logic;
  aresetn          : in std_logic;
  
  sts_data         : out std_logic_vector(BRAM_ADDR_WIDTH-1 downto 0);

  -- Slave side
  s_axis_tready    : out std_logic;
  s_axis_tdata     : in std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
  s_axis_tvalid    : in std_logic;

  -- BRAM port
  bram_porta_clk   : out std_logic;
  bram_porta_rst   : out std_logic;
  bram_porta_addr  : out std_logic_vector(BRAM_ADDR_WIDTH-1 downto 0);
  bram_porta_wrdata: out std_logic_vector(BRAM_DATA_WIDTH-1 downto 0);
  bram_porta_we    : out std_logic_vector(BRAM_DATA_WIDTH/8-1 downto 0)
);
end axis_bram_writer;

architecture rtl of axis_bram_writer is
  signal int_addr_reg, int_addr_next : std_logic_vector(BRAM_ADDR_WIDTH-1 downto 0);
  signal int_enbl_reg, int_enbl_next : std_logic;
  signal s_aux1                      : std_logic;

begin

  process(aclk)
  begin
    if rising_edge(aclk) then
      if (aresetn = '0') then
        int_addr_reg <= (others => '0');
        int_enbl_reg <= '0';
      else
        int_addr_reg <= int_addr_next;
        int_enbl_reg <= int_enbl_next;
      end if;
    end if;
  end process;

  -- Next state logic
  int_addr_next <= std_logic_vector(unsigned(int_addr_reg)+1) when (s_axis_tvalid = '1') and (int_enbl_reg = '1') else
                   int_addr_reg;

  int_enbl_next <= '1' when int_enbl_reg = '0' else
                   int_enbl_reg;

  sts_data <= int_addr_reg;

  s_axis_tready <= int_enbl_reg;

  s_aux1 <= s_axis_tvalid and int_enbl_reg;

  bram_porta_clk <= aclk;
  bram_porta_rst <= not aresetn;
  bram_porta_addr <= int_addr_reg;
  bram_porta_wrdata <= s_axis_tdata;
  bram_porta_we <= ((BRAM_DATA_WIDTH/8-1) downto 0 => s_aux1); 

end rtl;
