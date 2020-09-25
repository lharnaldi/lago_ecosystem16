library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axis_bram_reader is
  generic (
            BRAM_ADDR_WIDTH   : natural := 10;
            BRAM_DATA_WIDTH   : natural := 32;
            AXIS_TDATA_WIDTH  : natural := 32
          );
  port (
         -- System signals
         aclk             : in std_logic;
         aresetn          : in std_logic;

         cfg_data         : in std_logic_vector(BRAM_ADDR_WIDTH-1 downto 0);
         sts_data         : out std_logic_vector(BRAM_ADDR_WIDTH-1 downto 0);

         -- Master side
         m_axis_tready    : in std_logic;
         m_axis_tdata     : out std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
         m_axis_tvalid    : out std_logic;
         m_axis_tlast     : out std_logic;

         --m_axis_config_tready : in std_logic;
         --m_axis_config_tvalid : out std_logic;

         -- BRAM port
         bram_porta_clk   : out std_logic;
         bram_porta_rst   : out std_logic;
         bram_porta_addr  : out std_logic_vector(BRAM_ADDR_WIDTH-1 downto 0);
         bram_porta_rddata: in std_logic_vector(BRAM_DATA_WIDTH-1 downto 0)
       );
end axis_bram_reader;

architecture rtl of axis_bram_reader is

  signal addr_reg, addr_next     : unsigned(BRAM_ADDR_WIDTH-1 downto 0);
  signal addr_dly_reg, addr_dly_next : unsigned(BRAM_ADDR_WIDTH-1 downto 0);
  signal tlast_reg, tlast_next   : std_logic;
  signal comp_reg, comp_next     : std_logic;

begin

  process(aclk)
  begin
    if rising_edge(aclk) then
      if aresetn = '0' then
        addr_reg <= (others => '0');
        comp_reg <= '0';
        addr_dly_reg <= (others => '0');
        tlast_reg <= '0';
      else 
        addr_reg <= addr_next;
        comp_reg <= comp_next;
        addr_dly_reg <= addr_dly_next;
        tlast_reg <= tlast_next;
      end if;
    end if;
  end process;

  -- Next state logic
  comp_next <= '0' when (addr_reg = unsigned(cfg_data)) else
               '1';

  tlast_next <= '1' when (addr_reg = unsigned(cfg_data)-1) else
                '0';

  addr_next <= addr_reg + 1 when (m_axis_tready = '1') and (comp_reg = '1') else
               (others => '0') when (comp_reg = '0') else
               addr_reg;

  addr_dly_next <= addr_reg;

  --tvalid_next <= '1' when (tvalid_reg = '0') and (comp_reg = '1') else 
  --							 '0' when 
  --							 tvalid_reg;

  sts_data <= std_logic_vector(addr_dly_reg);

  m_axis_tdata  <= bram_porta_rddata;
  m_axis_tvalid <= comp_reg;
  m_axis_tlast  <= tlast_reg;

  bram_porta_clk <= aclk;
  bram_porta_rst <= not aresetn;
  bram_porta_addr <= std_logic_vector(addr_next);

end rtl;
