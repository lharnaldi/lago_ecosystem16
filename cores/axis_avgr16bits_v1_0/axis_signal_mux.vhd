library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axis_signal_mux is
generic (
      AXIS_DWIDTH : natural := 32
);
port (
  sel               : in std_logic;

  s0_axis_tdata     : in std_logic_vector(AXIS_DWIDTH-1 downto 0);        
  s0_axis_tvalid    : in std_logic;                               
  s0_axis_tready    : out std_logic;                               
  s0_axis_tlast     : in std_logic;                               
  s0_axis_tkeep     : in std_logic_vector(2-1 downto 0);        

  s1_axis_tdata     : in std_logic_vector(AXIS_DWIDTH-1 downto 0);  
  s1_axis_tvalid    : in std_logic;                         
  s1_axis_tready    : out std_logic;                         
  s1_axis_tlast     : in std_logic;                               
  s1_axis_tkeep     : in std_logic_vector(2-1 downto 0);        

  m_axis_tdata      : out std_logic_vector(AXIS_DWIDTH-1 downto 0);  
  m_axis_tvalid     : out std_logic;                         
  m_axis_tlast      : out std_logic;                               
  m_axis_tkeep      : out std_logic_vector(2-1 downto 0);        
  m_axis_tready     : in std_logic                         
);
end axis_signal_mux;

architecture rtl of axis_signal_mux is
begin

  s0_axis_tready <= m_axis_tready when sel = '0' else '0';
  s1_axis_tready <= m_axis_tready when sel = '1' else '0';

  m_axis_tdata  <= s0_axis_tdata when sel = '0' else s1_axis_tdata;
  m_axis_tvalid <= s0_axis_tvalid when sel = '0' else s1_axis_tvalid;
  m_axis_tlast  <= s0_axis_tlast when sel = '0' else s1_axis_tlast;
  m_axis_tkeep  <= s0_axis_tkeep when sel = '0' else s1_axis_tkeep;

end rtl;
