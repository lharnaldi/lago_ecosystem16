library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axis_bram_reader is
  generic (
  CONTINUOUS        : string  := "FALSE";
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

  m_axis_config_tready : in std_logic;
  m_axis_config_tvalid : out std_logic;

  -- BRAM port
  bram_porta_clk   : out std_logic;
  bram_porta_rst   : out std_logic;
  bram_porta_addr  : out std_logic_vector(BRAM_ADDR_WIDTH-1 downto 0);
  bram_porta_rddata: in std_logic_vector(BRAM_DATA_WIDTH-1 downto 0)
);
end axis_bram_reader;

architecture rtl of axis_bram_reader is

  signal int_addr_reg, 
         int_addr_next,
         sum_cntr_wire,
         int_data_reg   : std_logic_vector(BRAM_ADDR_WIDTH-1 downto 0);
  signal int_comp_wire, 
         int_tlast_wire,
         int_enbl_reg, 
         int_enbl_next,
         int_conf_reg, 
         int_conf_next  : std_logic;

begin
  
  process(aclk)
  begin
    if rising_edge(aclk) then
      if aresetn = '0' then
        int_addr_reg <= (others => '0');
        int_data_reg <= (others => '0');
        int_enbl_reg <= '0';
        int_conf_reg <= '0';
      else 
        int_addr_reg <= int_addr_next;
        int_data_reg <= cfg_data;
        int_enbl_reg <= int_enbl_next;
        int_conf_reg <= int_conf_next;
      end if;
   end if;
  end process;
 
  -- Next state logic
  sum_cntr_wire <= std_logic_vector(unsigned(int_addr_reg) + 1);
  int_comp_wire <= '1' when (unsigned(int_addr_reg) < unsigned(int_data_reg)) else '0';
  int_tlast_wire <= not int_comp_wire;

  CONTINUOUS_G: if (CONTINUOUS = "TRUE") generate
  begin
    int_addr_next <= sum_cntr_wire when (m_axis_tready = '1' and int_enbl_reg = '1' and int_comp_wire = '1') else
                     (others => '0') when (m_axis_tready = '1' and int_enbl_reg = '1' and int_tlast_wire = '1') else
                     int_addr_reg;

    int_enbl_next <= '1' when (int_enbl_reg = '0' and int_comp_wire = '1') else 
                     int_enbl_reg;
  end generate;

  STOP_G: if (CONTINUOUS = "FALSE") generate
  begin
    int_addr_next <= sum_cntr_wire when (m_axis_tready = '1' and int_enbl_reg = '1' and int_comp_wire = '1') else
                     int_addr_reg;

    int_enbl_next <= '1' when (int_enbl_reg = '0' and int_comp_wire = '1') else
                     '0' when (m_axis_tready = '1' and int_enbl_reg = '1' and int_tlast_wire = '1') else
                     int_enbl_reg;
    int_conf_next <= '1' when (m_axis_tready = '1' and int_enbl_reg = '1' and int_tlast_wire = '1') else
                     '0' when (int_conf_reg = '1' and m_axis_config_tready = '1') else
                     int_conf_reg;
  end generate;

  sts_data <= int_addr_reg;

  m_axis_tdata <= bram_porta_rddata;
  m_axis_tvalid <= int_enbl_reg;
  m_axis_tlast <= '1' when (int_enbl_reg = '1' and int_tlast_wire = '1') else '0';

  m_axis_config_tvalid <= int_conf_reg;

  bram_porta_clk <= aclk;
  bram_porta_rst <= not aresetn;
  bram_porta_addr <= int_addr_next when (m_axis_tready = '1' and int_enbl_reg = '1') else 
                     int_addr_reg;

end rtl;
