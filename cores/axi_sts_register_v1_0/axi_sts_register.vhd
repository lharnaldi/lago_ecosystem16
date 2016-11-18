library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity axi_sts_register is
  generic (
  STS_DATA_WIDTH : integer := 1024;
  AXI_DATA_WIDTH : integer := 32;
  AXI_ADDR_WIDTH: integer := 32
);
port (
  -- System signals
  aclk: in std_logic;
  aresetn : in std_logic;

  -- Status bits
  sts_data : in std_logic_vector(STS_DATA_WIDTH-1 downto 0);

  -- Slave side
  s_axi_awaddr: in std_logic_vector(AXI_ADDR_WIDTH-1 downto 0);  -- AXI4-Lite slave: Write address
  s_axi_awvalid: in std_logic; -- AXI4-Lite slave: Write address valid
  s_axi_awready: out std_logic; -- AXI4-Lite slave: Write address ready
  s_axi_wdata: in std_logic_vector(AXI_DATA_WIDTH-1 downto 0);   -- AXI4-Lite slave: Write data
  s_axi_wvalid: in std_logic;  -- AXI4-Lite slave: Write data valid
  s_axi_wready: out std_logic;  -- AXI4-Lite slave: Write data ready
  s_axi_bresp: out std_logic_vector(1 downto 0);   -- AXI4-Lite slave: Write response
  s_axi_bvalid: out std_logic;  -- AXI4-Lite slave: Write response valid
  s_axi_bready: in std_logic;  -- AXI4-Lite slave: Write response ready
  s_axi_araddr: in std_logic_vector(AXI_ADDR_WIDTH-1 downto 0);  -- AXI4-Lite slave: Read address
  s_axi_arvalid: in std_logic; -- AXI4-Lite slave: Read address valid
  s_axi_arready: out std_logic; -- AXI4-Lite slave: Read address ready
  s_axi_rdata: out std_logic_vector(AXI_DATA_WIDTH-1 downto 0);   -- AXI4-Lite slave: Read data
  s_axi_rresp: out std_logic_vector(1 downto 0);   -- AXI4-Lite slave: Read data response
  s_axi_rvalid: out std_logic;  -- AXI4-Lite slave: Read data valid
  s_axi_rready: in std_logic   -- AXI4-Lite slave: Read data ready
);
end axi_sts_register;

architecture rtl of axi_sts_register is

function clogb2 (value: natural) return integer is
    variable temp    : integer := value;
    variable ret_val : integer := 1; 
  begin					
    while temp > 1 loop
      ret_val := ret_val + 1;
      temp    := temp / 2;     
    end loop;
  	
    return ret_val;
  end function;

function sel(cond: boolean; if_true, if_false: integer) return integer is 
    begin 
        if (cond = true) then 
            return(if_true); 
        else 
            return(if_false); 
        end if; 
    end function; 

  constant ADDR_LSB : integer := clogb2(AXI_DATA_WIDTH/8 - 1);
  constant STS_SIZE : integer := STS_DATA_WIDTH/AXI_DATA_WIDTH;
  constant STS_WIDTH : integer := sel((STS_SIZE > 1), clogb2(STS_SIZE-1), 1);

  signal int_rvalid_reg, int_rvalid_next: std_logic;
  signal int_rdata_reg, int_rdata_next: std_logic_vector(AXI_DATA_WIDTH-1 downto 0);

  type int_data_mux_t is array (STS_SIZE-1 downto 0) of std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
  signal int_data_mux: int_data_mux_t;	

begin

  WORDS: for j in 0 to STS_SIZE-1 generate 
     int_data_mux(j) <= sts_data(j*AXI_DATA_WIDTH+AXI_DATA_WIDTH-1 downto j*AXI_DATA_WIDTH);
  end generate;

  process(aclk, aresetn)
  begin
    if(aresetn = '0') then
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

  int_rdata_next <= int_data_mux(to_integer(unsigned(s_axi_araddr(ADDR_LSB+STS_WIDTH-1 downto ADDR_LSB)))) when (s_axi_arvalid = '1') else
                    int_rdata_reg;

  s_axi_rresp <= (others => '0');

  s_axi_arready <= '1';
  s_axi_rdata <= int_rdata_reg;
  s_axi_rvalid <= int_rvalid_reg;

end rtl;
