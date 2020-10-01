library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axis_bram_sel is
  generic (
            BRAM_DATA_WIDTH    : natural := 32;
            BRAM_ADDR_WIDTH    : natural := 14  -- 2^11 = 2048 positions
          );
  port (
         -- System signals
         aclk             : in std_logic;

         sel              : in std_logic;

         -- BRAM PORT A
         bram_porta_clk   : in std_logic;
         bram_porta_rst   : in std_logic;
         bram_porta_addr  : in std_logic_vector(BRAM_ADDR_WIDTH-1 downto 0);
         bram_porta_wrdata: in std_logic_vector(BRAM_DATA_WIDTH-1 downto 0);
         bram_porta_rddata: out std_logic_vector(BRAM_DATA_WIDTH-1 downto 0);
         bram_porta_we    : in std_logic;

         -- BRAM PORT B
         bram_portb_clk   : in std_logic;
         bram_portb_rst   : in std_logic;
         bram_portb_addr  : in std_logic_vector(BRAM_ADDR_WIDTH-1 downto 0);
         bram_portb_wrdata: in std_logic_vector(BRAM_DATA_WIDTH-1 downto 0);
         bram_portb_rddata: out std_logic_vector(BRAM_DATA_WIDTH-1 downto 0);
         bram_portb_we    : in std_logic;

         -- BRAM PORT C
         bram_portc_clk   : out std_logic;
         bram_portc_rst   : out std_logic;
         bram_portc_addr  : out std_logic_vector(BRAM_ADDR_WIDTH-1 downto 0);
         bram_portc_wrdata: out std_logic_vector(BRAM_DATA_WIDTH-1 downto 0);
         bram_portc_rddata: in std_logic_vector(BRAM_DATA_WIDTH-1 downto 0);
         bram_portc_we    : out std_logic
       );
end axis_bram_sel;

architecture rtl of axis_bram_sel is

begin

  bram_portc_rst    <= bram_porta_rst when (sel = '1') else
                       bram_portb_rst;
  bram_portc_addr   <= bram_porta_addr when (sel = '1') else
                       bram_portb_addr;
  bram_portc_wrdata <= bram_porta_wrdata when (sel = '1') else
                       bram_portb_wrdata;
  bram_portc_we     <= bram_porta_we when (sel = '1') else 
                       bram_portb_we;

  bram_porta_rddata <= bram_portc_rddata when (sel = '1') else
                       (others => '0');
  bram_portb_rddata <= bram_portc_rddata when (sel = '0') else
                       (others => '0');

  BUFGMUX_inst: BUFGMUX 
  port map (
             O  => bram_portc_clk, -- 1-bit output: Clock output
             I0 => bram_portb_clk, -- 1-bit input: Clock input (S=0)
             I1 => bram_porta_clk, -- 1-bit input: Clock input (S=1)
             S  => sel             -- 1-bit input: Clock select
           );

end rtl;
