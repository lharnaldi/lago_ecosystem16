library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axis_packetizer is
  generic (
  AXIS_TDATA_WIDTH : natural := 32;
  CNTR_WIDTH    : natural    := 32;
  CONTINUOUS    : string     := "FALSE"
);
port (
  -- System signals
  aclk          : in std_logic;
  aresetn       : in std_logic;

  -- Configuration bits
  cfg_data      : in std_logic_vector(CNTR_WIDTH-1 downto 0);

  -- Slave side
  s_axis_tready : out std_logic;
  s_axis_tdata  : in std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
  s_axis_tvalid : in std_logic;

  --Master side
  m_axis_tready : in std_logic;
  m_axis_tdata  : out std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
  m_axis_tvalid : out std_logic;
  m_axis_tlast  : out std_logic
);
end axis_packetizer;

architecture rtl of axis_packetizer is

  signal int_cntr_reg, int_cntr_next : unsigned(CNTR_WIDTH-1 downto 0);
  signal int_enbl_reg, int_enbl_next : std_logic;

  signal int_comp_wire, int_tvalid_wire, int_tlast_wire : std_logic;

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

  int_comp_wire   <= '1' when (int_cntr_reg < unsigned(cfg_data)) else '0';
  int_tvalid_wire <= '1' when (int_enbl_reg = '1') and (s_axis_tvalid = '1') else '0';
  int_tlast_wire  <= '1' when (int_comp_wire = '0') else '0';

  CONTINUOUS_G: if (CONTINUOUS = "TRUE") generate
  begin
  int_cntr_next <= int_cntr_reg + 1 when (m_axis_tready = '1') and (int_tvalid_wire = '1') and (int_comp_wire = '1') else 
                   (others => '0') when (m_axis_tready = '1') and (int_tvalid_wire = '1') and (int_tlast_wire = '1') else 
		   int_cntr_reg;

  int_enbl_next <= '1' when (int_enbl_reg = '0') and (int_comp_wire = '1') else int_enbl_reg;
  end generate;

  STOP_G: if (CONTINUOUS = "FALSE") generate
  begin
  int_cntr_next <= int_cntr_reg + 1 when (m_axis_tready = '1') and (int_tvalid_wire = '1') and (int_comp_wire = '1') else 
                   int_cntr_reg;

  int_enbl_next <= '1' when (int_enbl_reg = '0') and (int_comp_wire = '1') else 
                   '0' when (m_axis_tready = '1') and (int_tvalid_wire = '1') and (int_tlast_wire = '1') else 
		   int_enbl_reg;
  end generate;

  s_axis_tready <= '1' when (int_enbl_reg = '1') and (m_axis_tready = '1') else '0';
  m_axis_tdata  <= s_axis_tdata;
  m_axis_tvalid <= int_tvalid_wire;
  m_axis_tlast  <= '1' when (int_enbl_reg = '1') and (int_tlast_wire = '1') else '0';

end rtl;
