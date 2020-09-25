library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axis_validator is
  generic (
            AXIS_TDATA_WIDTH  : natural := 32
          );
  port (
         -- System signals
         aclk             : in std_logic;
         trg_flag         : in std_logic;

         -- Slave side
         s_axis_tready    : out std_logic;
         s_axis_tdata     : in std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
         s_axis_tvalid    : in std_logic;

         -- Master side
         m_axis_tready    : in std_logic;
         m_axis_tdata     : out std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
         m_axis_tvalid    : out std_logic
       );
end axis_validator;

architecture rtl of axis_validator is

begin

  s_axis_tready <= m_axis_tready;
  m_axis_tdata  <= s_axis_tdata;
  m_axis_tvalid <= '1' when ((s_axis_tvalid = '1') and (trg_flag = '1')) else
                   '0';
end rtl;
