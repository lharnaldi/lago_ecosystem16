library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axis_trigger is
  generic (
  AXIS_TDATA_WIDTH : natural := 32;
  AXIS_TDATA_SIGNED : string := "FALSE"
);
port (
  -- System signals
  aclk: in std_logic;

  pol_data : in std_logic;
  msk_data : in std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
  lvl_data : in std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);

  trg_flag : out std_logic;

  -- Slave side
  s_axis_tready     : out std_logic;
  s_axis_tdata      : in std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
  s_axis_tvalid     : in std_logic
);
end axis_trigger;

architecture rtl of axis_trigger is

  signal int_comp_reg : std_logic_vector(1 downto 0);
  signal int_comp_wire : std_logic;

begin
    
  SIGNED_G: if (AXIS_TDATA_SIGNED = "TRUE") generate
    int_comp_wire <= '1' when signed(s_axis_tdata and msk_data) >= signed(lvl_data) else '0';
  end generate;

  UNSIGNED_G: if (AXIS_TDATA_SIGNED = "FALSE") generate
    int_comp_wire <= '1' when unsigned(s_axis_tdata and msk_data) >= unsigned(lvl_data) else '0';
  end generate;

  process(aclk, s_axis_tvalid)
  begin
   if (rising_edge(aclk)) then
    if (s_axis_tvalid = '1') then
      int_comp_reg <= int_comp_reg(0) & int_comp_wire;
    end if;
   end if;
  end process;

  s_axis_tready <= '1';

  trg_flag <= s_axis_tvalid and (pol_data xor int_comp_reg(0)) and (pol_data xor not(int_comp_reg(1)));

end rtl;
