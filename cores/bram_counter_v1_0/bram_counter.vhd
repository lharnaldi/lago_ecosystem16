library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity bram_counter is
				generic (
												BRAM_DATA_WIDTH : natural := 32;
												BRAM_ADDR_WIDTH : natural := 14
								);
				port (
										 -- System signals
										 aclk              : in std_logic;
										 aresetn           : in std_logic;

										 cfg_data           : in std_logic_vector(BRAM_DATA_WIDTH-1 downto 0);

										 -- BRAM port
										 bram_porta_clk    : out std_logic;
										 bram_porta_rst    : out std_logic;
										 bram_porta_addr   : out std_logic_vector(BRAM_ADDR_WIDTH-1 downto 0);
										 bram_porta_wrdata : out std_logic_vector(BRAM_DATA_WIDTH-1 downto 0);
										 bram_porta_rddata : in std_logic_vector(BRAM_DATA_WIDTH-1 downto 0);
										 bram_porta_we     : out std_logic
						 );

end bram_counter;

architecture rtl of bram_counter is

				signal cntr_reg, cntr_next   : unsigned(BRAM_DATA_WIDTH-1 downto 0);
				signal comp_reg, comp_next   : std_logic;
				signal addr_reg, addr_next   : unsigned(BRAM_ADDR_WIDTH-1 downto 0);
				signal wren_reg, wren_next   : std_logic;


begin

				bram_porta_clk    <= aclk;
				bram_porta_rst    <= not aresetn;
				bram_porta_addr   <= std_logic_vector(addr_reg);
				bram_porta_wrdata <= std_logic_vector(cntr_reg);
				bram_porta_we     <= wren_reg;

				process(aclk)
				begin
								if (rising_edge(aclk)) then
												if(aresetn = '0') then
																addr_reg <= (others => '0');
																cntr_reg <= (others => '0');
																comp_reg <= '0';
																wren_reg <= '0';
												else
																addr_reg <= addr_next;
																cntr_reg <= cntr_next;
																comp_reg <= comp_next;
																wren_reg <= wren_next;
												end if;
								end if;
				end process;

				wren_next <= '0' when (cntr_reg = unsigned(cfg_data)-1) else
										 '1';

				comp_next <= '0' when (cntr_reg = unsigned(cfg_data)-1) else 
										 '1';

				addr_next <= addr_reg + 1 when (comp_reg = '1') else
										 (others => '0') when (comp_reg = '0') else --reset
										 addr_reg;

				cntr_next <= cntr_reg + 1 when (comp_reg = '1') else
										 (others => '0') when (comp_reg = '0') else --reset
										 cntr_reg;

		
end rtl;
