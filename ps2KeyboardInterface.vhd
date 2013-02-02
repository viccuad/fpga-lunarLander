LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;

ENTITY ps2KeyboardInterface IS
  PORT (
    clk: IN std_logic;
    rst: IN std_logic;
    ps2Clk: IN std_logic;
    ps2Data: IN std_logic;        
    data: OUT std_logic_vector (7 DOWNTO 0);
    newData: OUT std_logic;
    newDataAck: IN std_logic
  );
END ps2KeyboardInterface;

ARCHITECTURE ps2KeyboardInterfaceArch OF ps2KeyboardInterface IS

  SIGNAL ldData, validData, lastBitRcv, ps2ClkSync, ps2ClkFallingEdge: std_logic;
  SIGNAL ps2DataRegOut: std_logic_vector(10 DOWNTO 0);
  SIGNAL goodParity: std_logic;

BEGIN

  synchronizer:
  PROCESS (rst, clk)
    VARIABLE aux1: std_logic;
  BEGIN
    IF (rst='0') THEN
      aux1 := '1';
      ps2ClkSync <= '1';
    ELSIF (clk'EVENT AND clk='1') THEN
      ps2ClkSync <= aux1;
      aux1 := ps2Clk;           
    END IF;
  END PROCESS synchronizer;

  edgeDetector: 
  PROCESS (rst, clk)
    VARIABLE aux1, aux2: std_logic;
  BEGIN
    ps2ClkFallingEdge <= (NOT aux1) AND aux2;
    IF (rst='0') THEN
      aux1 := '1';
      aux2 := '1';
    ELSIF (clk'EVENT AND clk='1') THEN
      aux2 := aux1;
      aux1 := ps2ClkSync;           
    END IF;
  END PROCESS edgeDetector;

  ps2DataReg:
  PROCESS (rst, clk)
  BEGIN
    IF (rst='0') THEN
      ps2DataRegOut <= (OTHERS =>'1');    
    ELSIF (clk'EVENT AND clk='1') THEN
      IF (lastBitRcv='1') THEN
        ps2DataRegOut <= (OTHERS=>'1'); 	
      ELSIF (ps2ClkFallingEdge='1') THEN
        ps2DataRegOut <= ps2Data & ps2DataRegOut(10 downto 1);
      END IF;
    END IF;
  END PROCESS ps2DataReg;

  oddParityCheker:
  goodParity <= 
    ((ps2DataRegOut(9) XOR ps2DataRegOut(8)) XOR (ps2DataRegOut(7) XOR ps2DataRegOut(6)))
    XOR ((ps2DataRegOut(5) XOR ps2DataRegOut(4)) XOR (ps2DataRegOut(3) XOR ps2DataRegOut(2)))
    XOR ps2DataRegOut(1);

  lastBitRcv <= NOT ps2DataRegOut(0);	

  validData <= lastBitRcv AND goodParity;

  dataReg:
  PROCESS (rst, clk)
  BEGIN
    IF (rst='0') THEN
      data <= (OTHERS=>'0');
    ELSIF (clk'EVENT AND clk='1') THEN
      IF (ldData='1') THEN
        data <= ps2DataRegOut(8 downto 1);
      END IF;
    END IF;
  END PROCESS dataReg;

  controller:
  PROCESS (validData, rst, clk)
    TYPE states IS (waitingData, waitingNewDataAck); 
    VARIABLE state: states;
  BEGIN
    ldData <= '0';
    newData <= '0';
    CASE state IS
      WHEN waitingData =>
        IF (validData='1') THEN
          ldData <= '1';
        END IF;
      WHEN waitingNewDataAck =>
        newData <= '1';
      WHEN OTHERS => NULL;
    END CASE;
    IF (rst='0') THEN
      state := waitingData;
    ELSIF (clk'EVENT AND clk='1') THEN
      CASE state IS
        WHEN waitingData =>
          IF (validData='1') THEN
            state := waitingNewDataAck;
          END IF;
        WHEN waitingNewDataAck =>
          IF (newDataAck='1') THEN
            state := waitingData;
          END IF;
        WHEN OTHERS => NULL;
      END CASE;
    END IF;
  END PROCESS controller;

END ps2KeyboardInterfaceArch;

