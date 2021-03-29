library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axis_signal_selector is
generic (
      AXIS_DWIDTH : natural := 32
);
port (
  sel                : in std_logic;
  -- System signals
  s_axis_aclk        : in std_logic;
  s_axis_aresetn     : in std_logic;
  s_axis_tdata       : in std_logic_vector(AXIS_DWIDTH-1 downto 0);        
  s_axis_tvalid      : in std_logic;                               
  s_axis_tready      : out std_logic;                               

  m0_axis_aclk       : out std_logic;
  m0_axis_aresetn    : out std_logic;
  m0_axis_tdata      : out std_logic_vector(AXIS_DWIDTH-1 downto 0);  
  m0_axis_tvalid     : out std_logic;                         
  m0_axis_tready     : in std_logic;                         

  m1_axis_aclk       : out std_logic;
  m1_axis_aresetn    : out std_logic;
  m1_axis_tdata      : out std_logic_vector(AXIS_DWIDTH-1 downto 0);  
  m1_axis_tvalid     : out std_logic;                         
  m1_axis_tready     : in std_logic                         
);
end axis_signal_selector;

architecture rtl of axis_signal_selector is
begin
  m0_axis_aclk    <= s_axis_aclk; 
  m0_axis_aresetn <= s_axis_aresetn; 

  m1_axis_aclk    <= s_axis_aclk; 
  m1_axis_aresetn <= s_axis_aresetn; 

  s_axis_tready <= m0_axis_tready when sel = '0' else m1_axis_tready;

  m0_axis_tvalid <= s_axis_tvalid when sel = '0' else '0';
  m0_axis_tdata  <= s_axis_tdata when sel = '0' else (others => '0');

  m1_axis_tvalid <= s_axis_tvalid when sel = '1' else '0';
  m1_axis_tdata  <= s_axis_tdata when sel = '1' else (others => '0');

end rtl;
