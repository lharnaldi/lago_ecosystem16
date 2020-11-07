library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axi_bram_reader is
  generic (
            AXI_DATA_WIDTH    : natural := 32;
            AXI_ADDR_WIDTH    : natural := 16;
            BRAM_ADDR_WIDTH   : natural := 10;
            BRAM_DATA_WIDTH   : natural := 32
          );
  port (
         -- System signals
         aclk             : in std_logic;
         aresetn          : in std_logic;

         -- Slave side
         s_axi_awaddr  : in  std_logic_vector(AXI_ADDR_WIDTH-1 downto 0);  -- AXI4-Lite slave: Write address
         s_axi_awvalid : in  std_logic;                                    -- AXI4-Lite slave: Write address valid
         s_axi_awready : out std_logic;                                    -- AXI4-Lite slave: Write address ready
         s_axi_wdata   : in  std_logic_vector(AXI_DATA_WIDTH-1 downto 0);  -- AXI4-Lite slave: Write data
         s_axi_wvalid  : in  std_logic;                                    -- AXI4-Lite slave: Write data valid
         s_axi_wready  : out std_logic;                                    -- AXI4-Lite slave: Write data ready
         s_axi_bresp   : out std_logic_vector(1 downto 0);                 -- AXI4-Lite slave: Write response
         s_axi_bvalid  : out std_logic;                                    -- AXI4-Lite slave: Write response valid
         s_axi_bready  : in  std_logic;                                    -- AXI4-Lite slave: Write response ready
         s_axi_araddr  : in  std_logic_vector(AXI_ADDR_WIDTH-1 downto 0);  -- AXI4-Lite slave: Read address
         s_axi_arvalid : in  std_logic;                                    -- AXI4-Lite slave: Read address valid
         s_axi_arready : out std_logic;                                    -- AXI4-Lite slave: Read address ready
         s_axi_rdata   : out std_logic_vector(AXI_DATA_WIDTH-1 downto 0);  -- AXI4-Lite slave: Read data
         s_axi_rresp   : out std_logic_vector(1 downto 0);                 -- AXI4-Lite slave: Read data response
         s_axi_rvalid  : out std_logic;                                    -- AXI4-Lite slave: Read data valid
         s_axi_rready  : in  std_logic;                                    -- AXI4-Lite slave: Read data ready

         -- BRAM port
         bram_porta_clk : out std_logic;  
         bram_porta_rst : out std_logic;
         bram_porta_addr: out std_logic_vector(BRAM_ADDR_WIDTH-1 downto 0);
         bram_porta_rddata : in std_logic_vector(BRAM_DATA_WIDTH-1 downto 0)
       );
end axi_bram_reader;

architecture rtl of axi_bram_reader is

  function clogb2 (value: natural) return natural is
  variable temp    : natural := value;
  variable ret_val : natural := 1;
  begin
    while temp > 1 loop
      ret_val := ret_val + 1;
      temp    := temp / 2;
    end loop;
    return ret_val;
  end function;

  constant ADDR_LSB : natural := clogb2((AXI_DATA_WIDTH/8) - 1);

  signal int_rvalid_reg, int_rvalid_next : std_logic;

begin

  process(aclk)
  begin
    if rising_edge(aclk) then
      if (aresetn = '0') then
        int_rvalid_reg <= '0';
      else
        int_rvalid_reg <= int_rvalid_next;
      end if;
    end if;
  end process;

  -- Next state logic
  int_rvalid_next <= '1' when (s_axi_arvalid = '1') else
                     '0' when (s_axi_rready = '1' and int_rvalid_reg = '1') else
                     int_rvalid_reg;

  s_axi_rresp <= (others => '0');

  s_axi_arready <= '1';
  s_axi_rdata <= bram_porta_rddata;
  s_axi_rvalid <= int_rvalid_reg;

  bram_porta_clk <= aclk;
  bram_porta_rst <= not aresetn;
  bram_porta_addr <= s_axi_araddr(ADDR_LSB+BRAM_ADDR_WIDTH-1 downto ADDR_LSB);

end rtl;
