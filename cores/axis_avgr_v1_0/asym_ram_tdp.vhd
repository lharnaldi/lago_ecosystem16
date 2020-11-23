library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity asym_ram_tdp is
  generic (
            WIDTHA      : integer   := 4;
            --SIZEA       : integer   := 1024;
            ADDRWIDTHA  : integer   := 10;
            WIDTHB      : integer   := 16;
            --SIZEB       : integer   := 256;
            ADDRWIDTHB  : integer   := 8 
          );
  port (
         clka        : in  std_logic;
         clkb        : in  std_logic;
         ena         : in  std_logic;
         enb         : in  std_logic;
         wea         : in  std_logic;
         web         : in  std_logic;
         addra       : in  std_logic_vector(ADDRWIDTHA-1 downto 0);
         addrb       : in  std_logic_vector(ADDRWIDTHB-1 downto 0);
         dia         : in  std_logic_vector(WIDTHA-1 downto 0);
         dib         : in  std_logic_vector(WIDTHB-1 downto 0);
         doa         : out std_logic_vector(WIDTHA-1 downto 0);
         dob         : out std_logic_vector(WIDTHB-1 downto 0)
       );
end asym_ram_tdp;


architecture asym_ram_tdp_arc of asym_ram_tdp is

  function max(L, R: INTEGER) return INTEGER is
  begin
    if L > R then
      return L;
    else
      return R;
    end if;
  end;

  function min(L, R: INTEGER) return INTEGER is
  begin
    if L < R then
      return L;
    else
      return R;
    end if;
  end;

  function log2 (val: INTEGER) return natural is
    variable res : natural;
  begin
    for i in 0 to 31 loop
      if (val <= (2**i)) then
        res := i;
        exit;
      end if;
    end loop;
    return res;
  end function log2;

  constant SIZEA    : integer := 2**ADDRWIDTHA;
  constant SIZEB    : integer := 2**ADDRWIDTHB;
  constant minWIDTH : integer := min(WIDTHA,WIDTHB);
  constant maxWIDTH : integer := max(WIDTHA,WIDTHB);
  constant maxSIZE  : integer := max(SIZEA,SIZEB);
  constant RATIO    : integer := maxWIDTH / minWIDTH;

  -- An asymmetric RAM is modeled in a similar way as a symmetric RAM, with an
  -- array of array object. Its aspect ratio corresponds to the port with the lower
  -- data width (larger depth).
  type ramType is array (0 to maxSIZE-1) of std_logic_vector(minWIDTH-1 downto 0);

  shared variable ram : ramType := (others => (others => '0'));

  signal readA  : std_logic_vector(WIDTHA-1 downto 0):= (others => '0');
  signal readB  : std_logic_vector(WIDTHB-1 downto 0):= (others => '0');
  signal regA   : std_logic_vector(WIDTHA-1 downto 0):= (others => '0');
  signal regB   : std_logic_vector(WIDTHB-1 downto 0):= (others => '0');

begin

  process (clka)
  begin
    if rising_edge(clka) then
      if ena = '1' then
        readA <= ram(to_integer(unsigned(addra)));
        if wea = '1' then 
          ram(to_integer(unsigned(addra))) := dia;
        end if;
      end if;
      regA <= readA;
    end if;
  end process;

  process (clkb)
  begin
    if rising_edge(clkb) then
      for i in 0 to RATIO-1 loop
        if enb = '1' then
          readB((i+1)*minWIDTH-1 downto i*minWIDTH) <= ram(to_integer(unsigned(addrb) & to_unsigned(i,log2(RATIO))));
          if web = '1' then
            ram(to_integer(unsigned(addrb) & to_unsigned(i,log2(RATIO)))) := dib((i+1)*minWIDTH-1 downto i*minWIDTH);
          end if;              
        end if;
      end loop;
      regB <= readB;
    end if;
  end process;

  doa <= regA;
  dob <= regB;

end asym_ram_tdp_arc;
