----------------------------------------------------------------------------------
-- Company: Neural Dream Reseach
-- Engineer: Ali Hakim Taşkıran
-- 
-- Create Date: 01/05/2024 09:24:57 PM
-- Design Name: Arithmetic Units
-- Module Name: Add-Subtract-Multiply
-- Project Name: Largon Accelerated Processing Units
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity HalfAdder is Port(a,b:in std_logic; c_out, sum:out std_logic); end HalfAdder;

architecture Behavioral of HalfAdder is
begin
    c_out<=a and b;
    sum<=a xor b;
end Behavioral;
------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity FullAdder is
    Port ( a : in STD_LOGIC;
           b : in STD_LOGIC;
           c_in : in STD_LOGIC;
           c_out : out STD_LOGIC;
           sum : out STD_LOGIC);
end FullAdder;

architecture Behavioral of FullAdder is

begin
    sum<=a xor b xor c_in;
    c_out<=((a xor b) and c_in) or (a and b);
end Behavioral;

------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity FixedPointAdder is -- a+b=c
    generic(N:integer:=32);
    port(a,b:in std_logic_vector(N-1 downto 0); c: out std_logic_vector(N-1 downto 0); overflow:out std_logic);
end FixedPointAdder;

architecture Behavioral of FixedPointAdder is
    signal c_inter: std_logic_vector(N-1 downto 0);
begin
    FA1: entity work.FullAdder port map(a=>a(0), b=>b(0), c_in=>'0', c_out=>c_inter(0), sum=>c(0));
    FA_array: for i in 1 to N-1 generate FA: entity work.FullAdder port map(a=>a(i), b=>b(i),c_in=>c_inter(i-1),c_out=>c_inter(i), sum=>c(i));
    end generate FA_array;
    overflow<=c_inter(N-1);

end architecture Behavioral;
-----------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity FixedPointSubtractor is -- a - b
    generic(N: integer:=32);
    port(a,b:in std_logic_vector(N-1 downto 0); c: out std_logic_vector(N-1 downto 0); overflow: out  std_logic);
end FixedPointSubtractor;

architecture Behavioral of FixedPointSubtractor is
    signal c_inter,b_inter: std_logic_vector(N-1 downto 0);
begin
    b_inter<=not(b);
    FA1: entity work.FullAdder port map(a=>a(0), b=>b_inter(0),c_in=>'1',c_out=>c_inter(0), sum=>c(0));
    FA_array: for i in 1 to N-1 generate FA: entity work.FullAdder port map(a=>a(i), b=>b_inter(i),c_in=>c_inter(i-1),c_out=>c_inter(i), sum=>c(i)); end generate FA_array;
    overflow<=not c_inter(N-1);
end Behavioral;
----------------------------------------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity FixedPointMultiplier_MixedPrecision is
    generic(N:integer:=128);
    port(a,b:in std_logic_vector(N-1 downto 0); c: out std_logic_vector(2*N-1 downto 0));
end FixedPointMultiplier_MixedPrecision;

architecture Behavioral of FixedPointMultiplier_MixedPrecision is
    signal anded: std_logic_vector(N**2-1 downto 0);
    signal sumout: std_logic_vector(N**2+N-1 downto 0);--N rows, N+1 cols
    signal carries: std_logic_vector(N-1 downto 0);
begin
    and_array: for i in 0 to N-1 generate 
        inner_loop: for j in 0 to N-1 generate
            gated: anded(N*i+j)<=a(j) and b(i); 
        end generate inner_loop; 
    end generate and_array;
    carries(0)<='0';
    sumout(N downto 1)<=anded(N-1 downto 0);

    add_array: for i in 1 to N-1 generate
        adder: entity work.FixedPointAdder generic map(N=>N+1) port map(a=>carries(i-1)&sumout((N+1)*(i)-1 downto (N+1)*(i-1)+1),
                                                                        b=>anded(N*(i+1)-1 downto N*i)&'0',
                                                                        overflow=>carries(i),
                                                                        c=>sumout((N+1)*(i+1)-1 downto (N+1)*i) );
    end generate add_array;

    outport1: for i in 0 to N-2 generate
        outport: c(i)<=sumout((N+1)*(i)+1);
    end generate outport1;

    c(2*N-2 downto N-1)<=sumout(N**2+N-1 downto N**2);
    c(2*N-1)<=carries(N-1);
end Behavioral;
----------------------------------------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity FixedPointFMA is
    generic(N:natural:=32);
    port(mul1, mul2, add: in std_logic_vector(N-1 downto 0); fused: out std_logic_vector(N-1 downto 0); overflow: out std_logic);
end FixedPointFMA;


architecture Behavioral of FixedPointFMA is
    signal distillate: std_logic_vector(2*N-1 downto 0);
    signal of_mul, of_add:std_logic;
begin


    multiplier: entity work.FixedPointMultiplier_MixedPrecision generic map(N=>N) port map(a=>mul1, b=>mul2, c=>distillate);
    process(distillate) begin
    if distillate(2*N-1 downto N) = (N-1 downto 0 => '0') then 
        of_mul<='0'; 
    else of_mul <= '1'; 
        end if;
    end process;
    adder: entity work.FixedPointAdder generic map(N=>N) port map(a=>distillate(N-1 downto 0), b=>add, c=>fused, overflow=>of_add);
    
    overflow<=of_mul or of_add;
end architecture Behavioral;
