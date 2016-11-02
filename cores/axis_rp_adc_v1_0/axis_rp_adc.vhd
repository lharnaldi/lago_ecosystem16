library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity axis_red_pitaya_adc is
  generic (
  ADC_DATA_WIDTH : integer := 14;
  AXIS_TDATA_WIDTH: integer := 32
);
port (
 	-- System signals
  adc_clk : out std_logic;

  -- ADC signals
  adc_csn : out std_logic;
  adc_clk_p : in std_logic;
  adc_clk_n : in std_logic;
  adc_dat_a : in std_logic_vector(ADC_DATA_WIDTH-1 downto 0);
  adc_dat_b : in std_logic_vector(ADC_DATA_WIDTH-1 downto 0);

  -- Master side
  m_axis_tvalid : out std_logic;
  m_axis_tdata : out std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0)
);
end axis_red_pitaya_adc;

architecture rtl of axis_red_pitaya_adc is

  constant PADDING_WIDTH : integer := AXIS_TDATA_WIDTH/2 - ADC_DATA_WIDTH;

  signal int_dat_a_reg : std_logic_vector(ADC_DATA_WIDTH-1 downto 0);
  signal int_dat_b_reg : std_logic_vector(ADC_DATA_WIDTH-1 downto 0);
  signal int_clk       : std_logic;
  signal dat_a_tmp, dat_b_tmp : signed(ADC_DATA_WIDTH-1 downto 0);

begin
  U1: IBUFGDS port map (I => adc_clk_p, IB => adc_clk_n, O => int_clk);

  process(int_clk)
  begin
	if rising_edge(int_clk) then 
    int_dat_a_reg <= adc_dat_a;
    int_dat_b_reg <= adc_dat_b;
  end if;
	end process;

  adc_clk <= int_clk;

  adc_csn <= '1';

  m_axis_tvalid <= '1';

  dat_a_tmp <= signed(int_dat_a_reg(ADC_DATA_WIDTH-1) & not int_dat_a_reg(ADC_DATA_WIDTH-2 downto 0));
  dat_b_tmp <= signed(int_dat_b_reg(ADC_DATA_WIDTH-1) & not int_dat_b_reg(ADC_DATA_WIDTH-2 downto 0));
  
  m_axis_tdata <= std_logic_vector(resize(dat_b_tmp, (m_axis_tdata'length/2)) & resize(dat_a_tmp, (m_axis_tdata'length/2)));

--  m_axis_tdata <= std_logic_vector(resize(int_dat_b_reg(ADC_DATA_WIDTH-1),(PADDING_WIDTH+1)) & not int_dat_b_reg(ADC_DATA_WIDTH-2 downto 0) &
--									resize(int_dat_a_reg(ADC_DATA_WIDTH-1),(PADDING_WIDTH+1)) & not int_dat_a_reg(ADC_DATA_WIDTH-2 downto 0));

end rtl;
