library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axi_time_trig_gen is
  generic (
            CFG_DATA_WIDTH  : natural := 64;
            AXI_DATA_WIDTH  : natural := 32;
            AXI_ADDR_WIDTH  : natural := 32
          );
  port (
         -- AXI INTERFACE CFG REGISTER
         s_axi_aclk     : in std_logic;
         s_axi_aresetn  : in std_logic;
         s_axi_awaddr   : in std_logic_vector(AXI_ADDR_WIDTH-1 downto 0);  
         s_axi_awvalid  : in std_logic;                                   
         s_axi_awready  : out std_logic;                                 
         s_axi_wdata    : in std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
         s_axi_wstrb    : in std_logic_vector(AXI_DATA_WIDTH/8-1 downto 0);
         s_axi_wvalid   : in std_logic;                                   
         s_axi_wready   : out std_logic;                                 
         s_axi_bresp    : out std_logic_vector(1 downto 0);             
         s_axi_bvalid   : out std_logic;                               
         s_axi_bready   : in std_logic;                               
         s_axi_araddr   : in std_logic_vector(AXI_ADDR_WIDTH-1 downto 0);
         s_axi_arvalid  : in std_logic;                                  
         s_axi_arready  : out std_logic;                                
         s_axi_rdata    : out std_logic_vector(AXI_DATA_WIDTH-1 downto 0); 
         s_axi_rresp    : out std_logic_vector(1 downto 0);               
         s_axi_rvalid   : out std_logic;                                 
         s_axi_rready   : in std_logic;                

         data_clk       : in std_logic;
         trig_o         : out std_logic
    );
end axi_time_trig_gen;

architecture rtl of axi_time_trig_gen is

  signal cntr_reg, cntr_next : std_logic_vector(CFG_DATA_WIDTH-1 downto 0);
  signal trig_reg, trig_next : std_logic;
  signal comp_reg, comp_next : std_logic;
  signal cfg_data_s          : std_logic_vector(CFG_DATA_WIDTH-1 downto 0);
  signal cfg_data_s_sync     : std_logic_vector(CFG_DATA_WIDTH-1 downto 0);
  signal cfg_data_comp       : std_logic_vector(32-1 downto 0);
  signal rstn_s              : std_logic;

begin

  --AXI interface cfg register
  cfg_i : entity work.axi_cfg_register
  generic map(
               CFG_DATA_WIDTH => CFG_DATA_WIDTH,
               AXI_DATA_WIDTH => AXI_DATA_WIDTH,
               AXI_ADDR_WIDTH => AXI_ADDR_WIDTH
             )
  port map(
            s_axi_aclk    => s_axi_aclk,   
            s_axi_aresetn => s_axi_aresetn,
            s_axi_awaddr  => s_axi_awaddr, 
            s_axi_awvalid => s_axi_awvalid,
            s_axi_awready => s_axi_awready,
            s_axi_wdata   => s_axi_wdata,  
            s_axi_wstrb   => s_axi_wstrb,  
            s_axi_wvalid  => s_axi_wvalid, 
            s_axi_wready  => s_axi_wready, 
            s_axi_bresp   => s_axi_bresp,  
            s_axi_bvalid  => s_axi_bvalid, 
            s_axi_bready  => s_axi_bready, 
            s_axi_araddr  => s_axi_araddr, 
            s_axi_arvalid => s_axi_arvalid,
            s_axi_arready => s_axi_arready,
            s_axi_rdata   => s_axi_rdata,  
            s_axi_rresp   => s_axi_rresp,  
            s_axi_rvalid  => s_axi_rvalid, 
            s_axi_rready  => s_axi_rready, 
            cfg_data      => cfg_data_s
          );

  -- synchronizer 0 from PS to PL clk -> PL
  sync0_i: entity work.shift_register
  generic map(
           SR_WIDTH => CFG_DATA_WIDTH,
           SR_DEPTH => 2
         )
  port map
  (
         aclk    => data_clk,
         aresetn => '1',
         en      => '1',
         data_i  => cfg_data_s,
         data_o  => cfg_data_s_sync
         );

  rstn_s        <= cfg_data_s_sync(32);
  cfg_data_comp <= cfg_data_s_sync(31 downto 0);

 process(data_clk)
  begin
    if rising_edge(data_clk) then
      if (rstn_s = '0') then
        cntr_reg <= (others => '0');
        trig_reg <= '0';
        comp_reg <= '0';
      else
        cntr_reg <= cntr_next;
        trig_reg <= trig_next;
        comp_reg <= comp_next;
      end if;
    end if;
  end process;
  
  comp_next <= '0' when (unsigned(cntr_reg) = unsigned(cfg_data_comp)-1) else 
               '1';

  cntr_next <= std_logic_vector(unsigned(cntr_reg) + 1) when (comp_reg = '1') else
               (others => '0') when (comp_reg = '0') else --reset
               cntr_reg;

  trig_next <= '1' when (unsigned(cntr_reg) = unsigned(cfg_data_comp)-1) else 
               '0';
 
  trig_o    <= trig_reg;

end rtl;
