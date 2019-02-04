library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity lpf_iir is
generic (
  AXIS_TDATA_WIDTH: natural := 32;
  ADC_DATA_WIDTH  : natural := 14
);
port(
  aclk       : in std_logic;
  aresetn    : in std_logic;
  tc_i       : in std_logic_vector (AXIS_TDATA_WIDTH-1 downto 0); -- time constant: parameter equal to e^-1/d where d is number of samples time constant
  data_o     : out std_logic_vector (AXIS_TDATA_WIDTH-1 downto 0);

  -- Slave side
  s_axis_tdata : in std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);  
  s_axis_tready: out std_logic;
  s_axis_tvalid: in std_logic; 

  -- Master side
  m_axis_tdata : out std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
  m_axis_tready: in std_logic;
  m_axis_tvalid: out std_logic

);
end lpf_iir;

architecture rtl of lpf_iir is

constant one               : std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0) := "01111111111111111111111111111111";

signal sig_reg, sig_next   : std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
signal data_reg, data_next : std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);

signal mult_out            : std_logic_vector(2*AXIS_TDATA_WIDTH-1 downto 0);

signal a0                  : std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
signal b1                  : std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);

begin

  process(aclk)
  begin
  	if(aresetn = '0') then
  		sig_reg <= s_axis_tdata;
      data_reg <= (others => '0');
  	elsif rising_edge(aclk) then
  		sig_reg <= sig_next;
      data_reg <= data_next;
  	end if;
  end process;

  --next state logic
  sig_next <= s_axis_tdata;
  s_axis_tready <= m_axis_tready;
  m_axis_tvalid <= s_axis_tvalid;
  
  a0 <= std_logic_vector(signed(one) - signed(tc_i)); --  & (AXIS_TDATA_WIDTH-2 downto 0 => '1') - signed(tc_i)); 
  b1 <= tc_i;  
  
  mult_out <= std_logic_vector(signed(a0)*signed(s_axis_tdata) + signed(b1)*signed(sig_reg));
  
  data_next <= mult_out((2*AXIS_TDATA_WIDTH)-1) & mult_out(2*AXIS_TDATA_WIDTH-2 downto 32);
  
  data_o <= data_reg;
  
  m_axis_tdata <= mult_out((2*AXIS_TDATA_WIDTH)-1) & mult_out(2*AXIS_TDATA_WIDTH-2 downto 32);

end rtl;
