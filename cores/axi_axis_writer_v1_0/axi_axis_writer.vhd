library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axi_axis_writer is
  generic (
    AXI_DATA_WIDTH : natural  := 32;
    AXI_ADDR_WIDTH : natural  := 32
);
port (
  -- System signals
  aclk : in std_logic;
  aresetn : in std_logic;
  
  -- Slave side
  s_axi_awaddr 	: in 	std_logic_vector(AXI_ADDR_WIDTH-1 downto 0);  -- AXI4-Lite slave: Write address
  s_axi_awvalid	: in 	std_logic; 			              -- AXI4-Lite slave: Write address valid
  s_axi_awready	: out std_logic; 			              -- AXI4-Lite slave: Write address ready
  s_axi_wdata	: in 	std_logic_vector(AXI_DATA_WIDTH-1 downto 0);  -- AXI4-Lite slave: Write data
  s_axi_wvalid	: in 	std_logic;  				      -- AXI4-Lite slave: Write data valid
  s_axi_wready	: out std_logic;  				      -- AXI4-Lite slave: Write data ready
  s_axi_bresp	: out std_logic_vector(1 downto 0);   		      -- AXI4-Lite slave: Write response
  s_axi_bvalid	: out std_logic;  				      -- AXI4-Lite slave: Write response valid
  s_axi_bready	: in 	std_logic;  				      -- AXI4-Lite slave: Write response ready
  s_axi_araddr	: in 	std_logic_vector(AXI_ADDR_WIDTH-1 downto 0);  -- AXI4-Lite slave: Read address
  s_axi_arvalid	: in 	std_logic; 				      -- AXI4-Lite slave: Read address valid
  s_axi_arready	: out std_logic; 				      -- AXI4-Lite slave: Read address ready
  s_axi_rdata	: out std_logic_vector(AXI_DATA_WIDTH-1 downto 0);    -- AXI4-Lite slave: Read data
  s_axi_rresp	: out	std_logic_vector(1 downto 0);   	      -- AXI4-Lite slave: Read data response
  s_axi_rvalid	: in 	std_logic;  				      -- AXI4-Lite slave: Read data valid
  s_axi_rready	: in 	std_logic;  				      -- AXI4-Lite slave: Read data ready
  
  -- Master side
  m_axis_tdata	: out std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
  m_axis_tvalid	: out std_logic
);
end axi_axis_writer;

architecture rtl of axi_axis_writer is

signal int_ready_reg, int_ready_next : std_logic;
signal int_valid_reg, int_valid_next : std_logic;
signal int_tdata_reg, int_tdata_next : std_logic_vector(AXI_DATA_WIDTH-1 downto 0);

begin

  process(aclk, aresetn)
  begin
    if (aresetn = '0') then
    	int_valid_reg <= '0';
    elsif rising_edge(aclk) then 
    	int_valid_reg <= int_valid_next;
    end if;
  end process;
  
  int_valid_next <= '1' when (s_axi_wvalid = '1') else 
                    '0' when (s_axi_bready = '1') and (int_valid_reg = '1') else
                    int_valid_reg;  
  
  s_axi_bresp <= (others => '0');
  
  s_axi_awready <= '1';
  s_axi_wready <= '1';
  s_axi_bvalid <= int_valid_reg;
  
  m_axis_tdata <= s_axi_wdata;
  m_axis_tvalid <= s_axi_wvalid;
  
end rtl;
