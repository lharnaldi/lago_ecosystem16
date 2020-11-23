library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fifo_write_ctrl is
  generic(
           N : natural := 4
         );
  port(
        clkw     : in std_logic;
        resetw   : in std_logic;
        wr       : in std_logic;
        r_ptr_in : in std_logic_vector(N downto 0);
        full     : out std_logic;
        w_ptr_out: out std_logic_vector(N downto 0);
        w_addr   : out std_logic_vector(N-1 downto 0)
      );
end fifo_write_ctrl;

architecture gray_arch of fifo_write_ctrl is
  signal w_ptr_reg, w_ptr_next :std_logic_vector(N downto 0);
  signal gray1, bin, bin1      : std_logic_vector(N downto 0);
  signal waddr_all             : std_logic_vector(N-1 downto 0);
  signal waddr_msb, raddr_msb  : std_logic;
  signal full_flag             : std_logic;

begin

  -- register
  process(clkw)
  begin
    if rising_edge(clkw) then
      if (resetw='0') then
        w_ptr_reg <= (others=>'0');
      else
        w_ptr_reg <= w_ptr_next;
      end if;
    end if;
  end process;

  -- (N+1)-bit Gray counter
  bin   <= w_ptr_reg xor ('0' & bin(N downto 1));
  bin1  <= std_logic_vector(unsigned(bin) + 1);
  gray1 <= bin1 xor ('0' & bin1(N downto 1));
  -- update write pointer
  w_ptr_next <= gray1 when wr='1' and full_flag='0' else
                w_ptr_reg;
  -- N-bit Gray counter
  waddr_msb <=  w_ptr_reg(N) xor w_ptr_reg(N-1);
  waddr_all <= waddr_msb & w_ptr_reg(N-2 downto 0);
  -- check for FIFO full
  raddr_msb <= r_ptr_in(N) xor r_ptr_in(N-1);
  full_flag <= '1' when r_ptr_in(N) /=w_ptr_reg(N) and
               r_ptr_in(N-2 downto 0)=w_ptr_reg(N-2 downto 0) and
               raddr_msb = waddr_msb else
               '0';
  -- output
  w_addr    <= waddr_all;
  w_ptr_out <= w_ptr_reg;
  full      <= full_flag;

end gray_arch;
