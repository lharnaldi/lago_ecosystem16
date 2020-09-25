library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity axis_rp_dac is
  generic (
  DAC_DATA_WIDTH : natural := 14;
  AXIS_TDATA_WIDTH: natural := 32
);
port (
  -- PLL signals
  aclk    : in std_logic;
  ddr_clk : in std_logic;
  wrt_clk : in std_logic;
  locked  : in std_logic;

  -- DAC signals
  dac_clk : out std_logic;
  dac_rst : out std_logic;
  dac_sel : out std_logic;
  dac_wrt : out std_logic;
  dac_dat : out std_logic_vector(DAC_DATA_WIDTH-1 downto 0);

  -- Slave side
  s_axis_tready : out std_logic;
  s_axis_tvalid : in std_logic;
  s_axis_tdata  : in std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0)
);
end axis_rp_dac;

architecture rtl of axis_rp_dac is

  signal int_dat_a_reg : std_logic_vector(DAC_DATA_WIDTH-1 downto 0);
  signal int_dat_b_reg : std_logic_vector(DAC_DATA_WIDTH-1 downto 0);
  signal int_rst_reg : std_logic;

  signal int_dat_a_wire : std_logic_vector(DAC_DATA_WIDTH-1 downto 0);
  signal int_dat_b_wire : std_logic_vector(DAC_DATA_WIDTH-1 downto 0);

begin
  int_dat_a_wire <= s_axis_tdata(DAC_DATA_WIDTH-1 downto 0);
  int_dat_b_wire <= s_axis_tdata(AXIS_TDATA_WIDTH/2+DAC_DATA_WIDTH-1 downto AXIS_TDATA_WIDTH/2);

  process(aclk)
  begin
  if rising_edge(aclk) then
    if (locked = '0' or s_axis_tvalid = '0') then
    int_dat_a_reg <= (others => '0');
    int_dat_b_reg <= (others => '0');
  else
    int_dat_a_reg <= int_dat_a_wire(DAC_DATA_WIDTH-1) & not int_dat_a_wire(DAC_DATA_WIDTH-2 downto 0);
    int_dat_b_reg <= int_dat_b_wire(DAC_DATA_WIDTH-1) & not int_dat_b_wire(DAC_DATA_WIDTH-2 downto 0);
    int_rst_reg <= not locked or not s_axis_tvalid;
  end if;
  end if;
  end process;

  ODDR_rst: ODDR port map (Q => dac_rst, D1 => int_rst_reg, D2 => int_rst_reg, C => aclk, CE => '1', R => '0', S => '0');
  ODDR_sel: ODDR port map (Q => dac_sel, D1 => '0', D2 => '1', C => aclk, CE => '1', R => '0', S => '0');
  ODDR_wrt: ODDR port map (Q => dac_wrt, D1 => '0', D2 => '1', C => wrt_clk, CE => '1', R => '0', S => '0');
  ODDR_clk: ODDR port map (Q => dac_clk, D1 => '0', D2 => '1', C => ddr_clk, CE => '1', R => '0', S => '0');
  
  DAC_DAT_inst: for j in 0 to DAC_DATA_WIDTH-1 generate
  ODDR_inst: ODDR port map(
    Q => dac_dat(j),
    D1 => int_dat_a_reg(j),
    D2 =>int_dat_b_reg(j),
    C => aclk,
    CE =>'1',
    R => '0',
    S => '0'
    );
  end generate;

  s_axis_tready <= '1';
	
end rtl;
