-- See WP279 from Xilinx
library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axis_dc_removal is
  generic(
           AXIS_TDATA_WIDTH : integer := 32
         );
  port (
         aclk    : in std_logic;
         aresetn : in std_logic;
         k1_i    : in std_logic_vector(AXIS_TDATA_WIDTH/2-1 downto 0);
         k2_i    : in std_logic_vector(AXIS_TDATA_WIDTH/2-1 downto 0);

         -- Slave side
         s_axis_tready     : out std_logic;
         s_axis_tdata      : in std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
         s_axis_tvalid     : in std_logic;

         -- Master side
         m_axis_tready     : in std_logic;
         m_axis_tdata      : out std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
         m_axis_tvalid     : out std_logic

       );
end axis_dc_removal;

architecture rtl of axis_dc_removal is

  signal d1_reg, d1_next : std_logic_vector(AXIS_TDATA_WIDTH/2-1 downto 0);
  signal d2_reg, d2_next : std_logic_vector(AXIS_TDATA_WIDTH/2-1 downto 0);
  signal d3_reg, d3_next : std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
  signal ch1_s, ch2_s    : std_logic_vector(AXIS_TDATA_WIDTH/2-1 downto 0);
  signal axis_tready     : std_logic;
  signal axis_tvalid     : std_logic;

begin

  axis_tready <= '1'; 
  s_axis_tready <= axis_tready; 
  m_axis_tvalid <= axis_tvalid;

  process(aclk)
  begin
    if rising_edge(aclk) then
      if aresetn = '0' then
        d1_reg <= (others => '0');     
        d2_reg <= (others => '0');     
        d3_reg <= (others => '0');     
      else
        d1_reg <= d1_next;
        d2_reg <= d2_next;
        d3_reg <= d3_next;
      end if;
    end if;
  end process;

  d1_next <= s_axis_tdata(AXIS_TDATA_WIDTH/2-1 downto 0) when
             ((axis_tready = '1') and (s_axis_tvalid = '1')) else
             d1_reg;
  d2_next <= s_axis_tdata(AXIS_TDATA_WIDTH-1 downto AXIS_TDATA_WIDTH/2)
             when ((axis_tready = '1') and (s_axis_tvalid = '1')) else
             d2_reg;

  d3_next <= ch2_s & ch1_s when ((m_axis_tready = '1') and (axis_tvalid = '1')) else 
             d3_reg;


  --dc removal for ch1
  ch1_dcrm: entity work.dc_removal
  port map(
            aclk     => aclk,
            aresetn  => aresetn,
            k_i      => k1_i,
            data_i   => d1_reg,
            data_o   => ch1_s
          );

  --dc removal for ch2
  ch2_dcrm: entity work.dc_removal
  port map(
            aclk     => aclk,
            aresetn  => aresetn,
            k_i      => k2_i,
            data_i   => d2_reg,
            data_o   => ch2_s
          );

  axis_tvalid <= '1';
  m_axis_tdata <= d3_reg;

end rtl;     
