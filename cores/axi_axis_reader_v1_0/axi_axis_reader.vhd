library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axi_axis_reader is
  generic (
    AXI_DATA_WIDTH : natural  := 32;
    AXI_ADDR_WIDTH : natural  := 32
);
port (
  -- System signals
  aclk          : in std_logic;
  aresetn       : in std_logic;
  
  -- Slave side
  s_axi_awaddr 	: in  std_logic_vector(AXI_ADDR_WIDTH-1 downto 0);  -- AXI4-Lite slave: Write address
  s_axi_awvalid	: in  std_logic; 			              -- AXI4-Lite slave: Write address valid
  s_axi_awready	: out std_logic; 			              -- AXI4-Lite slave: Write address ready
  s_axi_wdata	: in  std_logic_vector(AXI_DATA_WIDTH-1 downto 0);  -- AXI4-Lite slave: Write data
  s_axi_wvalid	: in  std_logic;  				      -- AXI4-Lite slave: Write data valid
  s_axi_wready	: out std_logic;  				      -- AXI4-Lite slave: Write data ready
  s_axi_bresp	: out std_logic_vector(1 downto 0);   		      -- AXI4-Lite slave: Write response
  s_axi_bvalid	: out std_logic;  				      -- AXI4-Lite slave: Write response valid
  s_axi_bready	: in  std_logic;  				      -- AXI4-Lite slave: Write response ready
  s_axi_araddr	: in  std_logic_vector(AXI_ADDR_WIDTH-1 downto 0);  -- AXI4-Lite slave: Read address
  s_axi_arvalid	: in  std_logic; 				      -- AXI4-Lite slave: Read address valid
  s_axi_arready	: out std_logic; 				      -- AXI4-Lite slave: Read address ready
  s_axi_rdata	: out std_logic_vector(AXI_DATA_WIDTH-1 downto 0);    -- AXI4-Lite slave: Read data
  s_axi_rresp	: out std_logic_vector(1 downto 0);   	      -- AXI4-Lite slave: Read data response
  s_axi_rvalid	: out std_logic;  				      -- AXI4-Lite slave: Read data valid
  s_axi_rready	: in  std_logic;  				      -- AXI4-Lite slave: Read data ready
  
  -- Slave side
  s_axis_tready : out std_logic;
  s_axis_tdata  : in std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
  s_axis_tvalid : in std_logic
);
end axi_axis_reader;

architecture rtl of axi_axis_reader is

signal int_rvalid_reg, int_rvalid_next : std_logic;
signal int_rdata_reg, int_rdata_next : std_logic_vector(AXI_DATA_WIDTH-1 downto 0);

begin

  process(aclk, aresetn)
  begin
    if (aresetn = '0') then
      int_rvalid_reg <= '0';
      int_rdata_reg <= (others => '0');
    elsif rising_edge(aclk) then 
      int_rvalid_reg <= int_rvalid_next;
      int_rdata_reg <= int_rdata_next;
    end if;
  end process;
  
  int_rvalid_next <= '1' when (s_axi_arvalid = '1') else 
                     '0' when (s_axi_rready = '1') and (int_rvalid_reg = '1') else
                     int_rvalid_reg;  
  
  int_rdata_next <= s_axis_tdata when (s_axi_arvalid = '1') and (s_axis_tvalid = '1') else
                    (others => '0') when (s_axi_arvalid = '1') and (s_axis_tvalid = '0') else
                    int_rdata_reg;

  s_axi_rresp <= (others => '0');
  
  s_axi_arready <= '1';
  s_axi_rdata <= int_rdata_reg;
  s_axi_rvalid <= int_rvalid_reg;
  
  s_axis_tready <= s_axi_rready and int_rvalid_reg;

end rtl;
