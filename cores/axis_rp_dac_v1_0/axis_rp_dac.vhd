--
-- Copyright (C) 2016 Horacio Arnaldi
-- e-mail: arnaldi@cab.cnea.gov.ar
--
-- Laboratorio de Detección de Partículas y Radiación
-- Centro Atómico Bariloche
-- Comisión Nacional de Energía Atómica (CNEA)
-- San Carlos de Bariloche
-- Date: 13/10/2016
-- Ver: v1r0  -- 
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--  
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.
--

library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;


entity axis_dac_itf is
  generic (
  DAC_DATA_WIDTH : integer := 16;
  AXIS_TDATA_WIDTH: integer := 32
);
port (
	aclk : in std_logic;

  -- DAC signals
  dac_data_clk_p : out std_logic;
  dac_data_clk_n : out std_logic;
  dac_dat : out std_logic_vector(DAC_DATA_WIDTH/2-1 downto 0);

  -- Slave side
  s_axis_tready : out std_logic;
  s_axis_tvalid : in std_logic;
  s_axis_tdata  : in std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0)
);
end axis_dac_itf;

architecture rtl of axis_dac_itf is

				constant VCC : std_logic := '1';
				constant GND : std_logic := '0';
  signal int_dat_reg, int_dat_next : std_logic_vector(DAC_DATA_WIDTH-1 downto 0);
	signal int_rst_reg, int_rst_next : std_logic;

	signal int_dat_wire : std_logic_vector(DAC_DATA_WIDTH-1 downto 0);

begin
  OBUFDS_inst : OBUFDS port map (O => dac_data_clk_p, OB => dac_data_clk_n, I => aclk);

  int_dat_wire <= s_axis_tdata(DAC_DATA_WIDTH-1 downto 0);
  int_dat_next <= int_dat_wire(DAC_DATA_WIDTH-1) & (not int_dat_wire(DAC_DATA_WIDTH-2 downto 0));

	process(aclk, s_axis_tvalid)
	begin
	  if (s_axis_tvalid = '0') then
		  int_dat_reg <= (others => '0');
	  elsif rising_edge(aclk) then
		  int_dat_reg <= int_dat_next;
		end if;
	end process;

	DAC_BUF: for j in 0 to DAC_DATA_WIDTH/2-1 generate
	  ODDR_inst: ODDR port map(
			        Q  => dac_dat(j),
							D1 => int_dat_reg(2*j),
						  D2 => int_dat_reg(2*j+1),
							C  => aclk,
							CE => VCC,
							R  => GND,
							S  => GND
			);
	end generate;

	s_axis_tready <= '1';
	
end rtl;
