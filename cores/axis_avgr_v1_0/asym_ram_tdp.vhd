library ieee;
use ieee.std_logic_1164.all;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity asym_ram_tdp is
    generic (
        INIT_RAM    : std_logic := '1';
        WIDTHA      : integer   := 4;
        --SIZEA       : integer   := 1024;
        ADDRWIDTHA  : integer   := 10;
        WIDTHB      : integer   := 16;
        --SIZEB       : integer   := 256;
        ADDRWIDTHB  : integer   := 8 
    );
    port (
        clkA        : in  std_logic;
        clkB        : in  std_logic;
        enA         : in  std_logic;
        enB         : in  std_logic;
        weA         : in  std_logic;
        weB         : in  std_logic;
        addrA       : in  std_logic_vector(ADDRWIDTHA-1 downto 0);
        addrB       : in  std_logic_vector(ADDRWIDTHB-1 downto 0);
        diA         : in  std_logic_vector(WIDTHA-1 downto 0);
        diB         : in  std_logic_vector(WIDTHB-1 downto 0);
        doA         : out std_logic_vector(WIDTHA-1 downto 0);
        doB         : out std_logic_vector(WIDTHB-1 downto 0)
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

shared variable my_ram : ramType := (others => (others => '0'));

signal readA  : std_logic_vector(WIDTHA-1 downto 0):= (others => '0');
signal readB  : std_logic_vector(WIDTHB-1 downto 0):= (others => '0');
signal regA   : std_logic_vector(WIDTHA-1 downto 0):= (others => '0');
signal regB   : std_logic_vector(WIDTHB-1 downto 0):= (others => '0');
 
--signal s_ram : ramType;
begin

    process (clkA)
    begin
      if rising_edge(clkA) then
        if enA = '1' then
          if weA = '1' then 
              my_ram(conv_integer(addrA)) := diA;
              --readA <= diA;
          else
              readA <= my_ram(conv_integer(addrA));
          end if;
        end if;
        regA <= readA;
        --s_ram <= my_ram;
      end if;
    end process;
        
    process (clkB)
        --variable test : std_logic_vector(WIDTHB-1 downto 0);
    begin
      if rising_edge(clkB) then
          for i in 0 to RATIO-1 loop
              if enB = '1' then
                  if weB = '1' then
                      my_ram(  conv_integer( addrB & conv_std_logic_vector(i,log2(RATIO)) )  ) := diB((i+1)*minWIDTH-1 downto i*minWIDTH);
                  end if;              
                  -- The read statement below is placed after the write statement on purpose to ensure write-first synchronization
                  -- through the variable mechanism
                  readB((i+1)*minWIDTH-1 downto i*minWIDTH) <= my_ram(  conv_integer( addrB & conv_std_logic_vector(i,log2(RATIO)) )  );
              end if;
          end loop;
          regB <= readB;
          --s_ram <= my_ram;
      end if;
    end process;
  
    doA <= regA;
    doB <= regB;

end asym_ram_tdp_arc;
