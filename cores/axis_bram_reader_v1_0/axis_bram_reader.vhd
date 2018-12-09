library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axis_bram_reader is
				generic (
												CONTINUOUS        : string  := "FALSE";
												BRAM_ADDR_WIDTH   : natural := 10;
												BRAM_DATA_WIDTH   : natural := 32;
												AXIS_TDATA_WIDTH  : natural := 32
								);
				port (
										 -- System signals
										 aclk             : in std_logic;
										 aresetn          : in std_logic;

										 cfg_data         : in std_logic_vector(BRAM_ADDR_WIDTH-1 downto 0);
										 sts_data         : out std_logic_vector(BRAM_ADDR_WIDTH-1 downto 0);

										 -- Master side
										 m_axis_tready    : in std_logic;
										 m_axis_tdata     : out std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
										 m_axis_tvalid    : out std_logic;
										 m_axis_tlast     : out std_logic;

										 --m_axis_config_tready : in std_logic;
										 --m_axis_config_tvalid : out std_logic;

										 -- BRAM port
										 bram_porta_clk   : out std_logic;
										 bram_porta_rst   : out std_logic;
										 bram_porta_addr  : out std_logic_vector(BRAM_ADDR_WIDTH-1 downto 0);
										 bram_porta_rddata: in std_logic_vector(BRAM_DATA_WIDTH-1 downto 0)
						 );
end axis_bram_reader;

architecture rtl of axis_bram_reader is

				signal addr_reg, addr_next : std_logic_vector(BRAM_ADDR_WIDTH-1 downto 0);
				signal data_reg, data_next : std_logic_vector(BRAM_ADDR_WIDTH-1 downto 0);
				signal comp_s              : std_logic; 
				signal tlast_s             : std_logic;
				signal enbl_reg, enbl_next : std_logic;
--signal conf_reg, conf_next : std_logic;

begin

				process(aclk)
				begin
								if rising_edge(aclk) then
												if aresetn = '0' then
																addr_reg <= (others => '0');
																data_reg <= (others => '0');
																enbl_reg <= '0';
												--conf_reg <= '0';
												else 
																addr_reg <= addr_next;
																data_reg <= data_next;
																enbl_reg <= enbl_next;
												--conf_reg <= conf_next;
												end if;
								end if;
				end process;

				-- Next state logic
				data_next <= cfg_data;

				comp_s <= '1' when (unsigned(addr_reg) < unsigned(data_reg)) else 
									'0';
				tlast_s <= not comp_s;

				CONTINUOUS_G: if (CONTINUOUS = "TRUE") generate
				begin
								addr_next <= std_logic_vector(unsigned(addr_reg) + 1) when (m_axis_tready = '1') and (enbl_reg = '1') and (comp_s = '1') else
														 (others => '0') when (m_axis_tready = '1') and (enbl_reg = '1') and (comp_s = '0') else
														 addr_reg;

								enbl_next <= '1' when (enbl_reg = '0') and (comp_s = '1') else 
														 enbl_reg;
				end generate;

				STOP_G: if (CONTINUOUS = "FALSE") generate
				begin
								addr_next <= std_logic_vector(unsigned(addr_reg) + 1) when (m_axis_tready = '1') and (enbl_reg = '1') and (comp_s = '1') else
														 addr_reg;

								enbl_next <= '1' when (m_axis_tready = '1') and (comp_s = '1') else
														 '0' when (m_axis_tready = '1') and (comp_s = '0') else
														 enbl_reg;

				--conf_next <= '1' when (m_axis_tready = '1') and (enbl_reg = '1') and (tlast_s = '1') else
				--						 '0' when (conf_reg = '1') and (m_axis_config_tready = '1') else
				--						 conf_reg;
				end generate;

				sts_data <= addr_reg;

				m_axis_tdata  <= bram_porta_rddata;
				m_axis_tvalid <= enbl_reg;
				m_axis_tlast  <= '1' when (enbl_reg = '1') and (tlast_s = '1') else 
												 '0';

				--m_axis_config_tvalid <= conf_reg;

				bram_porta_clk <= aclk;
				bram_porta_rst <= not aresetn;
				bram_porta_addr <= addr_reg;

end rtl;
