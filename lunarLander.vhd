

library IEEE;
library UNISIM;
use UNISIM.vcomponents.all;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- juego original lunar lander en: http://my.ign.com/atari/lunar-lander
-- para añadir letras: 
------https://github.com/FrankBuss/YaGraphCon
------http://www.frank-buss.de/yagraphcon/index.html
-- mas info:
------http://stackoverflow.com/questions/4179414/low-level-c-display-text-pixel-by-pixel
------http://www.angelcode.com/products/bmfont/


entity lunarLander is
	port (
    ps2Clk: IN std_logic;
    ps2Data: IN std_logic;
    clk: IN std_logic;
	 reset: IN std_logic;    --reset activo a baja!
	 hSync: OUT std_logic;
	 Vsync: OUT std_logic;
	 aterrizadoOUT: OUT std_logic;
	 segs: OUT std_logic_vector (6 downto 0);
	 R: OUT std_logic_vector (2 downto 0); -- alconversor D/A
	 G: OUT std_logic_vector (2 downto 0); -- alconversor D/A
	 B: OUT std_logic_vector (2 downto 0)  -- alconversor D/A
	);
end lunarLander;

 
architecture Behavioral of lunarLander is
 
	component ps2KeyboardInterface	
		port ( clk: IN std_logic;
				 rst: IN std_logic;
				 ps2Clk: IN std_logic;
				 ps2Data: IN std_logic;        
				 data: OUT std_logic_vector (7 DOWNTO 0);
				 newData: OUT std_logic;
				 newDataAck: IN std_logic
		);
	end component;  
	
	--seniales estados
	type fsmEstados is (pulsadas, despulsadas);
	signal estado: fsmEstados;
	type fsmEstados2 is (iniciando, jugando, parado, reseteo);
	signal estado2: fsmEstados2;
	
	--señales PS2
	signal newData, newDataAck: std_logic;
	signal scancode: std_logic_vector (7 downto 0);

	--señales VGA
	signal senialHSync, senialVSync: std_logic;
	signal finPixelCont: std_logic;
	signal cuentaPixelCont: std_logic_vector (10 downto 0);
	signal cuentaLineCont: std_logic_vector (9 downto 0);
	signal comp1, comp2, comp3, comp4, comp5, comp6: std_logic;	
	signal Rnave,Rmundo,Rbase,R_ml,R_l,R_r,R_mr,Rvel,Rfuego,Rfuel: std_logic_vector (2 downto 0); 
	signal Gnave,Gmundo,Gbase,G_ml,G_l,G_r,G_mr,Gvel,Gfuego,Gfuel: std_logic_vector (2 downto 0); 
	signal Bnave,Bmundo,Bbase,B_ml,B_l,B_r,B_mr,Bvel,Bfuego,Bfuel: std_logic_vector (2 downto 0);
	

	--señales juego
	signal pixelMundoHor, pixelNaveHor: std_logic_vector (7 downto 0); --153 pixeles (10011001)
	signal pixelMundoVer, pixelNaveVer,pixelAnteriorVer: std_logic_vector (6 downto 0); --102 pixeles
	signal regBaseDificil1,regBaseDificil2,regBaseFacil: std_logic_vector (6 downto 0); 
	signal contMod3: std_logic_vector(1 downto 0);
	signal clContMod3: std_logic;
	signal generarBases,INhaAterrizado,haAterrizado: std_logic;
	signal posNave: std_logic_vector (14 downto 0);  --pixelNaveHor catenado pixelNaveVer
	signal cuentaVelVertical, cuentaVelHorizontal: std_logic_vector (6 downto 0);  
	signal muyLentoVertical,lentoVertical,rapidoVertical,muyRapidoVertical: std_logic;
	signal muyLentoHorizontal,lentoHorizontal,rapidoHorizontal,muyRapidoHorizontal: std_logic;

	 --seniales registro lsfr
	signal D,Q: std_logic_vector (14 downto 0);
	signal puertaAND: std_logic_vector (0 downto 0);
	
	--seniales juego
	signal movNave: std_logic_vector (2 downto 0);  -- 000 = no se mueve , 001 = arriba , 010 = abajo , 011 = izquierda, 100 = derecha
	signal moverNave: std_logic;   
	signal teclaSPC,teclaW,teclaS,teclaA,teclaD: std_logic;
	signal clTeclaSPC,clTeclaW,clTeclaS,clTeclaA,clTeclaD: std_logic;
	signal ldTeclaSPC,ldTeclaW,ldTeclaS,ldTeclaA,ldTeclaD: std_logic;
	signal cuentaMuyRapido: STD_LOGIC_VECTOR(20 downto 0);  
	signal cuentaRapido: STD_LOGIC_VECTOR(21 downto 0); 
	signal cuentaLento: STD_LOGIC_VECTOR(22 downto 0);  
	signal cuentaMuyLento: STD_LOGIC_VECTOR(23 downto 0);  
	signal cuentaMuyMuyLento: STD_LOGIC_VECTOR(30 downto 0); 
	signal finCuentaMuyRapido,finCuentaRapido,finCuentaLento,finCuentaMuyLento,finCuentaMuyMuyLento: STD_LOGIC;
	signal cuentaContBarrido: std_logic_vector(14 downto 0);
	signal finCuentaBarrido,enableContBarrido,hayColision: std_logic;
	signal enableContMundo,finCuentaContMundoHor,pixelAleatorio: std_logic;
	
	--seniales memorias
	signal DOAmundoMenosSig,DOAmundoMasSig,DOBmundoMenosSig,DOBmundoMasSig: std_logic_vector(0 downto 0);
	signal selPixelPantalla: std_logic_vector (14 downto 0);  -- pixeles logicos hor (120) concatenado con pixeles logicos ver (153): cuentaPixelCont(10 downto 3)++cuentaLineCont(8 downto 2)
	signal selPixelMundo: std_logic_vector (14 downto 0);  --pixelMundoHor catenado pixelMundoVer
	signal WEBmenosSig,WEBmasSig,senialWEB,senialWEA: std_logic; 
	signal DIB,DOBmundo,DOAmundo: std_logic_vector(0 downto 0);

	--señales de depuracion
	signal st : std_logic_vector (2 downto 0); 

begin

--------------------------- RAM ------------------------------------------------
	aterrizadoOUT <= haAterrizado;

	selPixelMundo(14 downto 7) <= pixelMundoHor;
	selPixelMundo(6 downto 0) <= pixelMundoVer;
	
	selPixelPantalla(14 downto 7) <= cuentaPixelCont(10 downto 3);
	selPixelPantalla(6 downto 0) <= cuentaLineCont(8 downto 2); 
	
	
	--http://www.xilinx.com/itp/xilinx10/books/docs/spartan3_hdl/spartan3_hdl.pdf
	memMenosSignif: RAMB16_S1_S1
		generic map(
			WRITE_MODE_B => "READ_FIRST"
		)
		port map (
			DOA => DOAmundoMenosSig, -- Port A 1-bit Data Output
			DOB => DOBmundoMenosSig, -- Port B 2-bit Data Output
			ADDRA => selPixelPantalla(13 downto 0), -- Port A 14-bit Address Input
			ADDRB => selPixelMundo(13 downto 0), -- Port B 14-bit Address Input
			CLKA => clk, -- Port A Clock
			CLKB => clk, -- Port B Clock
			DIA => "0", -- Port A 1-bit Data Input
			DIB => DIB, -- Port B 1-bit Data Input --pintamos azul
			ENA => '1', -- Port A RAM Enable Input
			ENB => '1', -- PortB RAM Enable Input
			SSRA => '0', -- Port A Synchronous Set/Reset Input
			SSRB => '0', -- Port B Synchronous Set/Reset Input
			WEA => senialWEA, -- Port A Write Enable Input
			WEB => WEBmenosSig -- Port B Write Enable Input
		);
	
	memMasSignif: RAMB16_S1_S1
		generic map(
			WRITE_MODE_B => "READ_FIRST"
		)
		port map (
			DOA => DOAmundoMasSig, -- Port A 1-bit Data Output
			DOB => DOBmundoMasSig, -- Port B 1-bit Data Output
			ADDRA => selPixelPantalla(13 downto 0), -- Port A 14-bit Address Input
			ADDRB => selPixelMundo(13 downto 0), -- Port B 14-bit Address Input
			CLKA => clk, -- Port A Clock
			CLKB => clk, -- Port B Clock
			DIA => "0", -- Port A 1-bit Data Input
			DIB => DIB, -- Port B 1-bit Data Input --pintamos azul
			ENA => '1', -- Port A RAM Enable Input
			ENB => '1', -- PortB RAM Enable Input
			SSRA => '0', -- Port A Synchronous Set/Reset Input
			SSRB => '0', -- Port B Synchronous Set/Reset Input
			WEA => senialWEA, -- Port A Write Enable Input
			WEB => WEBmasSig -- Port B Write Enable Input
		);	
	
	interfazPS2: ps2KeyboardInterface port map (
														rst => reset,
														clk => clk,
														ps2Clk => ps2Clk,
														ps2Data => ps2Data,
														data => scancode, 
														newData => newData,
														newDataAck => newDataAck
													);


	decodMemorias: process(selPixelMundo,senialWEB,DOBmundoMenosSig,DOBmundoMasSig,
								  DOAmundoMenosSig,DOAmundoMasSig)
	begin
		
		if (selPixelMundo(14) = '0') then
			--direccionar a las menos signif
			WEBmenosSig <= senialWEB;
			WEBmasSig <= '0';
			DOBmundo <= DOBmundoMenosSig;
			DOAmundo <= DOAmundoMenosSig;
		else
			--direccionar a las mas signif
			WEBmenosSig <= '0';
			WEBmasSig <= senialWEB;
			DOBmundo <= DOBmundoMasSig;
			DOAmundo <= DOAmundoMasSig;
		end if;
		
	end process decodMemorias;
	
	


----------------------- PANTALLA -----------------------------------------------

	hSync <= senialHSync; 
	vSync <= senialVSync;

	pantalla: process(clk, reset,cuentaPixelCont,cuentaLineCont,Rnave,Rmundo,Gnave,Gmundo,
							Bnave,Bmundo,Rbase,Gbase,Bbase,Rvel,Gvel,Bvel,Rfuego,Gfuego,Bfuego,
							Rfuel,Gfuel,Bfuel,teclaW,cuentaMuyLento,teclaA,teclaD)
	begin
		
		--cont mod 1589 (pixelCont para sincronismo horizontal)
		if (cuentaPixelCont = "11000110100") then
			finPixelCont <= '1';
		else 
			finPixelCont <= '0';
		end if;
		
		if(reset = '0')then
			cuentaPixelCont <= (others => '0');
			finPixelCont <= '0';
		elsif(clk'event and clk = '1') then
				if (cuentaPixelCont /= "11000110100") then   --1588
					cuentaPixelCont  <= cuentaPixelCont + '1';  
				elsif (cuentaPixelCont = "11000110100") then
					cuentaPixelCont  <= (others => '0');	
				end if;
				
		end if;
		
		--cont mod 528 (lineCont para sincronismo vertical)
		if(reset = '0')then
			cuentaLineCont <= (others => '0');
		elsif(clk'event and clk = '1') then
				if (finPixelCont = '1' and cuentaLineCont /= "1000001111") then   --527
					cuentaLineCont  <= cuentaLineCont + '1';  
				elsif (finPixelCont = '1' and cuentaLineCont = "1000001111") then
					cuentaLineCont  <= (others => '0');
				end if;	
		end if;		
		
		--comparaciones para pintar dentro de los limites
		if (cuentaPixelCont > 1257) then  comp1 <= '1';  else  comp1 <= '0'; end if;
		if (cuentaPixelCont > 1304) then  comp2 <= '1';  else  comp2 <= '0'; end if;
		if (cuentaPixelCont <= 1493) then  comp3 <= '1';  else  comp3 <= '0'; end if;
		if (cuentaLineCont > 479) then  comp4 <= '1';  else  comp4 <= '0'; end if;
		if (cuentaLineCont > 493) then  comp5 <= '1';  else  comp5 <= '0'; end if;
		if (cuentaLineCont <= 495) then  comp6 <= '1';  else  comp6 <= '0'; end if;  
		
		
		senialHSync <= comp2 nand comp3;
		senialVSync <= comp5 nand comp6;
		
		if (senialHSync = '0' or senialVSync = '0') then --no pinta
			R <= "000";
			G <= "000";
			B <= "000";
		else --pintamos lo que tengamos que pintar
			R(2) <= ( (not (comp1 or comp4))  and  (Rnave(2) or Rmundo(2) or Rbase(2) or Rvel(2) or Rfuego(2) or Rfuel(2)) );
			R(1) <= ( (not (comp1 or comp4))  and  (Rnave(1) or Rmundo(1) or Rbase(1) or Rvel(1) or Rfuego(1) or Rfuel(1)) );
			R(0) <= ( (not (comp1 or comp4))  and  (Rnave(0) or Rmundo(0) or Rbase(0) or Rvel(0) or Rfuego(0) or Rfuel(0)) );
			G(2) <= ( (not (comp1 or comp4))  and  (Gnave(2) or Gmundo(2) or Gbase(2) or Gvel(2) or Gfuego(2) or Gfuel(2)) );
			G(1) <= ( (not (comp1 or comp4))  and  (Gnave(1) or Gmundo(1) or Gbase(1) or Gvel(1) or Gfuego(1) or Gfuel(1)) );
			G(0) <= ( (not (comp1 or comp4))  and  (Gnave(0) or Gmundo(0) or Gbase(0) or Gvel(0) or Gfuego(0) or Gfuel(0)) );
			B(2) <= ( (not (comp1 or comp4))  and  (Bnave(2) or Bmundo(2) or Bbase(2) or Bvel(2) or Bfuego(2) or Bfuel(2)) );
			B(1) <= ( (not (comp1 or comp4))  and  (Bnave(1) or Bmundo(1) or Bbase(1) or Bvel(1) or Bfuego(1) or Bfuel(1)) );
			B(0) <= ( (not (comp1 or comp4))  and  (Bnave(0) or Bmundo(0) or Bbase(0) or Bvel(0) or Bfuego(0) or Bfuel(0)) );
		end if;

	end process;
	

------------------ PINTAR JUEGO ------------------------------------------------
		
			-- vertical: 479 limite de pixeles visibles
			-- 120 pixeles -> 479            x= (479*1)/120 = 3.99 = aprox 4
			-- 1   pixeles -> x
			
			-- horizontal: 1257 limite de pixeles visibles
			-- 153 pixeles -> 1257           x= (1257*1)/153 = 8.21 = aprox 8
			-- 1   pixeles -> x

	
	pintarNave: process(cuentaLineCont,cuentaPixelCont,pixelNaveVer,pixelNaveHor)
	begin
		-- inicializacion
		Rnave <= "000";
		Gnave <= "000";
		Bnave <= "000";

		--pintar
		if (  (cuentaLineCont(9 downto 2) = pixelNaveVer-3 or cuentaLineCont(9 downto 2) = pixelNaveVer-1)
			and (cuentaPixelCont(10 downto 3) = pixelNaveHor) ) then 
				Rnave <= "000";
				Gnave <= "110";
				Bnave <= "000";
		end if;
		if ((cuentaLineCont(9 downto 2) = pixelNaveVer-2)
			and (cuentaPixelCont(10 downto 3) = pixelNaveHor)) then 
				Rnave <= "000";
				Gnave <= "000";
				Bnave <= "110";
		end if;
		if (((cuentaLineCont(9 downto 2) = pixelNaveVer) or (cuentaLineCont(9 downto 2) = pixelNaveVer-2))
			and (cuentaPixelCont(10 downto 3) = pixelNaveHor-1 )) then 	
				Rnave <= "000";
				Gnave <= "110";
				Bnave <= "000";
		end if;
		if (((cuentaLineCont(9 downto 2) = pixelNaveVer) or (cuentaLineCont(9 downto 2) = pixelNaveVer-2))
			and (cuentaPixelCont(10 downto 3) = pixelNaveHor+1 )) then 
				Rnave <= "000";
				Gnave <= "110";
				Bnave <= "000";
		end if;
	end process pintarNave;
	
	
	pintarFuego: process(cuentaLineCont,cuentaPixelCont,pixelNaveVer,pixelNaveHor,
								teclaW,cuentaMuyLento,teclaA,teclaD,cuentaMuyMuyLento)
	begin
		-- inicializacion
		Rfuego <= "000";
		Gfuego <= "000";
		Bfuego <= "000";
		
		if (teclaW = '1' and cuentaMuyLento(20 downto 20) = "1" and cuentaMuyMuyLento(30 downto 24) /= "0000000") then
			--pintar amarillo:abajo
			if ( cuentaLineCont(9 downto 2) = pixelNaveVer and cuentaPixelCont(10 downto 3) = pixelNaveHor) then 
					Rfuego <= "111";
					Gfuego <= "111";
					Bfuego <= "000";
			end if;
			--pintar amarillo:abajo
			if (cuentaLineCont(9 downto 2) = pixelNaveVer+1 and cuentaPixelCont(10 downto 3) = pixelNaveHor) then 
					Rfuego <= "111";
					Gfuego <= "111";
					Bfuego <= "000";
			end if;
			--pintar rojo:abajo
			if (((cuentaLineCont(9 downto 2) = pixelNaveVer+1))
				and ((cuentaPixelCont(10 downto 3) = pixelNaveHor+1 ) or (cuentaPixelCont(10 downto 3) = pixelNaveHor-1 ))) then 
					Rfuego <= "111";
					Gfuego <= "000";
					Bfuego <= "000";
			end if;
			if (cuentaLineCont(9 downto 2) = pixelNaveVer+2 and cuentaPixelCont(10 downto 3) = pixelNaveHor) then 
					Rfuego <= "111";
					Gfuego <= "000";
					Bfuego <= "000";
			end if;
		end if;
		--pintar fuego lateral a la derecha (voy a la izquierda), he apretado izq
		if (teclaA = '1' and cuentaMuyLento(20 downto 20) = "1") then
			if (cuentaLineCont(9 downto 2) = pixelNaveVer-2 and cuentaPixelCont(10 downto 3) = pixelNaveHor+2) then 
				Rfuego <= "111";
				Gfuego <= "000";
				Bfuego <= "000";
			end if;
		end if;
		--pintar fuego lateral a la izquierda (voy a la derecha) he apretado der
		if (teclaD = '1' and cuentaMuyLento(20 downto 20) = "1") then
			if (cuentaLineCont(9 downto 2) = pixelNaveVer-2 and cuentaPixelCont(10 downto 3) = pixelNaveHor-2) then 
				Rfuego <= "111";
				Gfuego <= "000";
				Bfuego <= "000";
			end if;
		end if;

	end process pintarFuego;
	 
	 
	pintarMundo: process(DOAmundo)
	begin
		-- inicializacion
		Rmundo <= "000";
		Gmundo <= "000";
		Bmundo <= "000";

		--pintar
		if (DOAmundo = "1") then
			Rmundo <= "011";
			Gmundo <= "011";
			Bmundo <= "011";
		end if;			
	end process pintarMundo;
	
	
	pintarBases: process(cuentaLineCont,cuentaPixelCont,DOAmundo,regBaseDificil1,
							regBaseDificil2,regBaseFacil)
	begin
		-- inicializacion
		Rbase <= "000";
		Gbase <= "000";
		Bbase <= "000";

		--pintar base3_1
		if (DOAmundo = "1" and 
			 (cuentaPixelCont(10 downto 3) >= regBaseDificil1 and 
			  cuentaPixelCont(10 downto 3) < regBaseDificil1 +5) ) then
			Rbase <= "000";
			Gbase <= "111";
			Bbase <= "000";
		end if;			
		--pintar base3_2
		if (DOAmundo = "1" and  
			 (cuentaPixelCont(10 downto 3) >= regBaseDificil2 and 
			  cuentaPixelCont(10 downto 3) < regBaseDificil2 +5) ) then
			Rbase <= "000";
			Gbase <= "111";
			Bbase <= "000";
		end if;		
		--pintar base facil
		if (DOAmundo = "1" and 
			 (cuentaPixelCont(10 downto 3) >= regBaseFacil and 
			  cuentaPixelCont(10 downto 3) < regBaseFacil +9) ) then
			Rbase <= "111";
			Gbase <= "000";
			Bbase <= "000";
		end if;		
	end process pintarBases;
	
	
	Rvel(2) <= (R_ml(2) or R_l(2) or R_r(2) or R_mr(2));
	Rvel(1) <= (R_ml(1) or R_l(1) or R_r(1) or R_mr(1));
	Rvel(0) <= (R_ml(0) or R_l(0) or R_r(0) or R_mr(0));
	Gvel(2) <= (G_ml(2) or G_l(2) or G_r(2) or G_mr(2));
	Gvel(1) <= (G_ml(1) or G_l(1) or G_r(1) or G_mr(1));
	Gvel(0) <= (G_ml(0) or G_l(0) or G_r(0) or G_mr(0));
	Bvel(2) <= (B_ml(2) or B_l(2) or B_r(2) or B_mr(2));
	Bvel(1) <= (B_ml(1) or B_l(1) or B_r(1) or B_mr(1));
	Bvel(0) <= (B_ml(0) or B_l(0) or B_r(0) or B_mr(0));
	
	
	pintarVelMuyLento: process(cuentaLineCont,cuentaPixelCont,cuentaVelVertical,cuentaVelHorizontal,
								muyLentoVertical,lentoVertical,rapidoVertical,muyRapidoVertical,
								muyLentoHorizontal,lentoHorizontal,rapidoHorizontal,muyRapidoHorizontal)
	begin
		-- inicializacion
		R_ml <= "000";
		G_ml <= "000";
		B_ml <= "000";

		--inicializar a gris:
		if ((cuentaLineCont(9 downto 2) >= 4 and cuentaLineCont(9 downto 2) <= 6)
			and (cuentaPixelCont(10 downto 3) >= 144 and cuentaPixelCont(10 downto 3) <= 146)) then 
				if ((cuentaLineCont(9 downto 2) /= 5) and (cuentaPixelCont(10 downto 3) /= 145)) then 
					R_ml <= "001";
					G_ml <= "001";
					B_ml <= "001";
				end if;
		end if;
		
		if (cuentaVelHorizontal >= 0 and cuentaVelHorizontal < 64) then --hor izq
			--pintar pixel muyLento
			if (muyLentoHorizontal = '1' or lentoHorizontal = '1' or rapidoHorizontal = '1' or muyRapidoHorizontal = '1') then
				if ((cuentaLineCont(9 downto 2) = 5) and (cuentaPixelCont(10 downto 3) = 144) ) then 
					R_ml <= "000";
					G_ml <= "111";
					B_ml <= "000";
				end if;
			end if;
		else -- hor derecha
			--pintar pixel muyLento
			if (muyLentoHorizontal = '1' or lentoHorizontal = '1' or rapidoHorizontal = '1' or muyRapidoHorizontal = '1') then
				if ((cuentaLineCont(9 downto 2) = 5) and (cuentaPixelCont(10 downto 3) = 146) ) then 
					R_ml <= "000";
					G_ml <= "111";
					B_ml <= "000";
				end if;
			end if;
		end if;
		
		if (cuentaVelVertical >= 0 and cuentaVelVertical < 64) then --ver subir
			--pintar pixel muyLento
			if (muyLentoVertical = '1' or lentoVertical = '1' or rapidoVertical = '1' or muyRapidoVertical = '1') then
				if ((cuentaLineCont(9 downto 2) = 4) and (cuentaPixelCont(10 downto 3) = 145) ) then 
					R_ml <= "000";
					G_ml <= "111";
					B_ml <= "000";
				end if;
			end if;
		else -- ver abajo
			--pintar pixel muyLento
			if (muyLentoVertical = '1' or lentoVertical = '1' or rapidoVertical = '1' or muyRapidoVertical = '1') then
				if ((cuentaLineCont(9 downto 2) = 6) and (cuentaPixelCont(10 downto 3) = 145) ) then 
					R_ml <= "000";
					G_ml <= "111";
					B_ml <= "000";
				end if;
			end if;
		end if;
	end process pintarVelMuyLento;

	
	pintarVelLento: process(cuentaLineCont,cuentaPixelCont,cuentaVelVertical,cuentaVelHorizontal,
							muyLentoVertical,lentoVertical,rapidoVertical,muyRapidoVertical,
							muyLentoHorizontal,lentoHorizontal,rapidoHorizontal,muyRapidoHorizontal)
	begin
		-- inicializacion
		R_l <= "000";
		G_l <= "000";
		B_l <= "000";

		--inicializar a gris:
		if ((cuentaLineCont(9 downto 2) >= 3 and cuentaLineCont(9 downto 2) <= 7)
			and (cuentaPixelCont(10 downto 3) >= 143 and cuentaPixelCont(10 downto 3) <= 147)) then 
				if ((cuentaLineCont(9 downto 2) /= 5) and (cuentaPixelCont(10 downto 3) /= 145)) then 
					R_l <= "011";
					G_l <= "011";
					B_l <= "011";
				end if;
		end if;
		
		if (cuentaVelHorizontal >= 0 and cuentaVelHorizontal < 64) then --hor izq
			--pintar pixel Lento
			if (lentoHorizontal = '1' or rapidoHorizontal = '1' or muyRapidoHorizontal = '1') then
				if ((cuentaLineCont(9 downto 2) = 5) and (cuentaPixelCont(10 downto 3) = 143) ) then 
					R_l <= "111";
					G_l <= "111";
					B_l <= "000";
				end if;
			end if;
		else -- hor derecha
			--pintar pixel Lento
			if (lentoHorizontal = '1' or rapidoHorizontal = '1' or muyRapidoHorizontal = '1') then
				if ((cuentaLineCont(9 downto 2) = 5) and (cuentaPixelCont(10 downto 3) = 147) ) then 
					R_l <= "111";
					G_l <= "111";
					B_l <= "000";
				end if;
			end if;
		end if;
		
		if (cuentaVelVertical >= 0 and cuentaVelVertical < 64) then --ver subir
			--pintar pixel Lento
			if (lentoVertical = '1' or rapidoVertical = '1' or muyRapidoVertical = '1') then
				if ((cuentaLineCont(9 downto 2) = 3) and (cuentaPixelCont(10 downto 3) = 145) ) then 
					R_l <= "111";
					G_l <= "111";
					B_l <= "000";
				end if;
			end if;
		else -- ver abajo
			--pintar pixel Lento
			if (lentoVertical = '1' or rapidoVertical = '1' or muyRapidoVertical = '1') then
				if ((cuentaLineCont(9 downto 2) = 7) and (cuentaPixelCont(10 downto 3) = 145) ) then 
					R_l <= "111";
					G_l <= "111";
					B_l <= "000";
				end if;
			end if;
		end if;
	end process pintarVelLento;
	
	
	pintarVelRapido: process(cuentaLineCont,cuentaPixelCont,cuentaVelVertical,cuentaVelHorizontal,
							muyLentoVertical,lentoVertical,rapidoVertical,muyRapidoVertical,
							muyLentoHorizontal,lentoHorizontal,rapidoHorizontal,muyRapidoHorizontal)
	begin
		-- inicializacion
		R_r <= "000";
		G_r <= "000";
		B_r <= "000";

		--inicializar a gris:
		if ((cuentaLineCont(9 downto 2) >= 2 and cuentaLineCont(9 downto 2) <= 8)
			and (cuentaPixelCont(10 downto 3) >= 142 and cuentaPixelCont(10 downto 3) <= 148)) then 
				if ((cuentaLineCont(9 downto 2) /= 5) and (cuentaPixelCont(10 downto 3) /= 145)) then 
					R_r <= "010";
					G_r <= "010";
					B_r <= "010";
				end if;
		end if;
		
		if (cuentaVelHorizontal >= 0 and cuentaVelHorizontal < 64) then --hor izq
			--pintar pixel 
			if (rapidoHorizontal = '1' or muyRapidoHorizontal = '1') then
				if ((cuentaLineCont(9 downto 2) = 5) and (cuentaPixelCont(10 downto 3) = 142) ) then 
					R_r <= "111";
					G_r <= "011";
					B_r <= "000";
				end if;
			end if;
		else -- hor derecha
			--pintar pixel 
			if (rapidoHorizontal = '1' or muyRapidoHorizontal = '1') then
				if ((cuentaLineCont(9 downto 2) = 5) and (cuentaPixelCont(10 downto 3) = 148) ) then 
					R_r <= "111";
					G_r <= "011";
					B_r <= "000";
				end if;
			end if;
		end if;
		
		if (cuentaVelVertical >= 0 and cuentaVelVertical < 64) then --ver subir
			--pintar pixel 
			if (rapidoVertical = '1' or muyRapidoVertical = '1') then
				if ((cuentaLineCont(9 downto 2) = 2) and (cuentaPixelCont(10 downto 3) = 145) ) then 
					R_r <= "111";
					G_r <= "011";
					B_r <= "000";
				end if;
			end if;
		else -- ver abajo
			--pintar pixel 
			if (rapidoVertical = '1' or muyRapidoVertical = '1') then
				if ((cuentaLineCont(9 downto 2) = 8) and (cuentaPixelCont(10 downto 3) = 145) ) then 
					R_r <= "111";
					G_r <= "011";
					B_r <= "000";
				end if;
			end if;
		end if;
	end process pintarVelRapido;
	
	
	pintarVelMuyRapido: process(cuentaLineCont,cuentaPixelCont,cuentaVelVertical,cuentaVelHorizontal,
								muyLentoVertical,lentoVertical,rapidoVertical,muyRapidoVertical,
								muyLentoHorizontal,lentoHorizontal,rapidoHorizontal,muyRapidoHorizontal)
	begin
		-- inicializacion
		R_mr <= "000";
		G_mr <= "000";
		B_mr <= "000";

		--inicializar a gris:
		if ((cuentaLineCont(9 downto 2) >= 1 and cuentaLineCont(9 downto 2) <= 9)
			and (cuentaPixelCont(10 downto 3) >= 141 and cuentaPixelCont(10 downto 3) <= 149)) then 
				if ((cuentaLineCont(9 downto 2) /= 5) and (cuentaPixelCont(10 downto 3) /= 145)) then 
					R_mr <= "000";
					G_mr <= "000";
					B_mr <= "000";
				end if;	
		end if;
		
		if (cuentaVelHorizontal >= 0 and cuentaVelHorizontal < 64) then --hor izq
			--pintar pixel 
			if (muyRapidoHorizontal = '1') then
				if ((cuentaLineCont(9 downto 2) = 5) and (cuentaPixelCont(10 downto 3) = 141) ) then 
					R_mr <= "111";
					G_mr <= "000";
					B_mr <= "000";
				end if;
			end if;
		else -- hor derecha
			--pintar pixel muyLento
			if (muyRapidoHorizontal = '1') then
				if ((cuentaLineCont(9 downto 2) = 5) and (cuentaPixelCont(10 downto 3) = 149) ) then 
					R_mr <= "111";
					G_mr <= "000";
					B_mr <= "000";
				end if;
			end if;
		end if;
		
		if (cuentaVelVertical >= 0 and cuentaVelVertical < 64) then --ver subir
			--pintar pixel muyLento
			if (muyRapidoVertical = '1') then
				if ((cuentaLineCont(9 downto 2) = 1) and (cuentaPixelCont(10 downto 3) = 145) ) then 
					R_mr <= "111";
					G_mr <= "000";
					B_mr <= "000";
				end if;
			end if;
		else -- ver abajo
			--pintar pixel muyLento
			if (muyRapidoVertical = '1') then
				if ((cuentaLineCont(9 downto 2) = 9) and (cuentaPixelCont(10 downto 3) = 145) ) then 
					R_mr <= "111";
					G_mr <= "000";
					B_mr <= "000";
				end if;
			end if;
		end if;
	end process pintarVelMuyRapido;
	
	
	pintarGasolina: process(cuentaLineCont,cuentaPixelCont,cuentaMuyMuyLento)
	begin
		-- inicializacion
		Rfuel <= "000";
		Gfuel <= "000";
		Bfuel <= "000";

		--linea gris:
		if ( cuentaLineCont(9 downto 2) = 7 and 
			  cuentaPixelCont(10 downto 3) >= 116 and cuentaPixelCont(10 downto 3) <= 127) then  
			Rfuel <= "111";
			Gfuel <= "111";
			Bfuel <= "111";
		end if;	
		
		--F de fuel
		if ( cuentaLineCont(9 downto 2) >= 4 and cuentaLineCont(9 downto 2) <= 7 and
			  cuentaPixelCont(10 downto 3) = 112) then  
			Rfuel <= "111";
			Gfuel <= "111";
			Bfuel <= "111";
		end if;
		if ( (cuentaLineCont(9 downto 2) = 4 or cuentaLineCont(9 downto 2) = 6) and
			  cuentaPixelCont(10 downto 3) = 113) then  
			Rfuel <= "111";
			Gfuel <= "111";
			Bfuel <= "111";
		end if;		
		
		--lineas rojas
		if ( cuentaLineCont(9 downto 2) >= 4 and cuentaLineCont(9 downto 2) <= 6 and
			  cuentaPixelCont(10 downto 3) = 116 and 
			  (cuentaMuyMuyLento(30 downto 24) > "0000000" and cuentaMuyMuyLento(30 downto 24) <= "1110111")) then  
			Rfuel <= "111";
			Gfuel <= "000";
			Bfuel <= "000";
		end if;
		if ( cuentaLineCont(9 downto 2) >= 4 and cuentaLineCont(9 downto 2) <= 6 and
			  cuentaPixelCont(10 downto 3) = 117 and 
			  (cuentaMuyMuyLento(30 downto 24) > "0001010" and cuentaMuyMuyLento(30 downto 24) <= "1110111")) then 
			Rfuel <= "111";
			Gfuel <= "000";
			Bfuel <= "000"; 
		end if;
		if ( cuentaLineCont(9 downto 2) >= 4 and cuentaLineCont(9 downto 2) <= 6 and
			  cuentaPixelCont(10 downto 3) = 118 and 
			  (cuentaMuyMuyLento(30 downto 24) > "0010100" and cuentaMuyMuyLento(30 downto 24) <= "1110111")) then 
			Rfuel <= "111";
			Gfuel <= "000";
			Bfuel <= "000";
		end if;		
		--lineas naranjas
		if ( cuentaLineCont(9 downto 2) >= 4 and cuentaLineCont(9 downto 2) <= 6 and
			  cuentaPixelCont(10 downto 3) = 119 and 
			  (cuentaMuyMuyLento(30 downto 24) > "0011110" and cuentaMuyMuyLento(30 downto 24) <= "1110111")) then  
			Rfuel <= "111";
			Gfuel <= "011";
			Bfuel <= "000";
		end if;
		if ( cuentaLineCont(9 downto 2) >= 4 and cuentaLineCont(9 downto 2) <= 6 and
			  cuentaPixelCont(10 downto 3) = 120 and 
			  (cuentaMuyMuyLento(30 downto 24) > "0101000" and cuentaMuyMuyLento(30 downto 24) <= "1110111")) then 
			Rfuel <= "111";
			Gfuel <= "011";
			Bfuel <= "000";
		end if;
		if ( cuentaLineCont(9 downto 2) >= 4 and cuentaLineCont(9 downto 2) <= 6 and
			  cuentaPixelCont(10 downto 3) = 121 and 
			  (cuentaMuyMuyLento(30 downto 24) > "0110010" and cuentaMuyMuyLento(30 downto 24) <= "1110111")) then 
			Rfuel <= "111";
			Gfuel <= "011";
			Bfuel <= "000";
		end if;
		--lineas amarillas
		if ( cuentaLineCont(9 downto 2) >= 4 and cuentaLineCont(9 downto 2) <= 6 and
			  cuentaPixelCont(10 downto 3) = 122 and 
			  (cuentaMuyMuyLento(30 downto 24) > "0111100" and cuentaMuyMuyLento(30 downto 24) <= "1110111")) then  
			Rfuel <= "111";
			Gfuel <= "111";
			Bfuel <= "000";
		end if;
		if ( cuentaLineCont(9 downto 2) >= 4 and cuentaLineCont(9 downto 2) <= 6 and
			  cuentaPixelCont(10 downto 3) = 123 and 
			  (cuentaMuyMuyLento(30 downto 24) > "1000110" and cuentaMuyMuyLento(30 downto 24) <= "1110111")) then 
			Rfuel <= "111";
			Gfuel <= "111";
			Bfuel <= "000";
		end if;
		if ( cuentaLineCont(9 downto 2) >= 4 and cuentaLineCont(9 downto 2) <= 6 and
			  cuentaPixelCont(10 downto 3) = 124 and 
			  (cuentaMuyMuyLento(30 downto 24) > "1010000" and cuentaMuyMuyLento(30 downto 24) <= "1110111")) then 
			Rfuel <= "111";
			Gfuel <= "111";
			Bfuel <= "000";
		end if;
		--lineas verdes
		if ( cuentaLineCont(9 downto 2) >= 4 and cuentaLineCont(9 downto 2) <= 6 and
			  cuentaPixelCont(10 downto 3) = 125 and 
			  (cuentaMuyMuyLento(30 downto 24) > "1011010" and cuentaMuyMuyLento(30 downto 24) <= "1110111")) then  
			Rfuel <= "000";
			Gfuel <= "111";
			Bfuel <= "000";
		end if;
		if ( cuentaLineCont(9 downto 2) >= 4 and cuentaLineCont(9 downto 2) <= 6 and
			  cuentaPixelCont(10 downto 3) = 126 and 
			  (cuentaMuyMuyLento(30 downto 24) > "1100100" and cuentaMuyMuyLento(30 downto 24) <= "1110111")) then 
			Rfuel <= "000";
			Gfuel <= "111";
			Bfuel <= "000";
		end if;
		if ( cuentaLineCont(9 downto 2) >= 4 and cuentaLineCont(9 downto 2) <= 6 and
			  cuentaPixelCont(10 downto 3) = 127 and 
			  (cuentaMuyMuyLento(30 downto 24) > "1101110" and cuentaMuyMuyLento(30 downto 24) <= "1110111") ) then 
			Rfuel <= "000";
			Gfuel <= "111";
			Bfuel <= "000";
		end if;
	end process pintarGasolina;
	
--#################### CONTROL JUEGO #########################################--
	
	
	contadorMuyRapido: process(reset,clk,cuentaMuyRapido)  --contador mod 2.000.000 (de 0 a 1.999.999)
	begin
		if (cuentaMuyRapido = "111101000010001111111") then
			finCuentaMuyRapido <= '1';
		else 
			finCuentaMuyRapido <= '0';
		end if;
		
		if(reset = '0')then
			cuentaMuyRapido <= (others => '0');
			finCuentaMuyRapido <= '0';
		elsif(clk'event and clk = '1') then
			if (cuentaMuyRapido /= "111101000010001111111") then  
				cuentaMuyRapido <= cuentaMuyRapido + 1; 
			elsif (cuentaMuyRapido = "111101000010001111111") then
				cuentaMuyRapido  <= (others => '0');
			end if;		
		end if;
	end process contadorMuyRapido;
	
		
	contadorRapido: process(reset,clk,cuentaRapido)  --contador mod 4.000.000 (de 0 a 3.999.999)
	begin
		if (cuentaRapido = "1111010000100011111111") then
			finCuentaRapido <= '1';
		else 
			finCuentaRapido <= '0';
		end if;
		
		if(reset = '0')then
			cuentaRapido <= (others => '0');
			finCuentaRapido <= '0';
		elsif(clk'event and clk = '1') then
			if (cuentaRapido /= "1111010000100011111111") then  
				cuentaRapido <= cuentaRapido + 1; 
			elsif (cuentaRapido = "1111010000100011111111") then
				cuentaRapido  <= (others => '0');
			end if;		
		end if;
	end process contadorRapido;
	
	
	contadorLento: process(reset,clk,cuentaLento)  --contador mod 8.000.000 (de 0 a 7.999.999)
	begin
		if (cuentaLento = "11110100001000111111111") then
			finCuentaLento <= '1';
		else 
			finCuentaLento <= '0';
		end if;
		
		if(reset = '0')then
			cuentaLento <= (others => '0');
			finCuentaLento <= '0';
		elsif(clk'event and clk = '1') then
			if (cuentaLento /= "11110100001000111111111") then  
				cuentaLento <= cuentaLento + 1; 
			elsif (cuentaLento = "11110100001000111111111") then
				cuentaLento  <= (others => '0');
			end if;		
		end if;
	end process contadorLento;
	
	
	contadorMuyLento: process(reset,clk,cuentaMuyLento)  --contador mod 16.000.000 (de 0 a 15.999.999)
	begin
		if (cuentaMuyLento = "11110100001000111111111111") then
			finCuentaMuyLento <= '1';
		else 
			finCuentaMuyLento <= '0';
		end if;
		
		if(reset = '0')then
			cuentaMuyLento <= (others => '0');
			finCuentaMuyLento <= '0';
		elsif(clk'event and clk = '1') then
			if (cuentaMuyLento /= "11110100001000111111111111") then  
				cuentaMuyLento <= cuentaMuyLento + 1; 
			elsif (cuentaMuyLento = "11110100001000111111111111") then
				cuentaMuyLento  <= (others => '0');
			end if;		
		end if;
	end process contadorMuyLento;
	
	
	contadorMuyMuyLento: process(reset,clk,cuentaMuyMuyLento,teclaSPC,pixelNaveVer)  --contador mod 32.000.000 (de 0 a 31.999.999)
	begin
		if (cuentaMuyMuyLento = "0000000000000000000000000000") then
			finCuentaMuyMuyLento <= '1';
		else 
			finCuentaMuyMuyLento <= '0';
		end if;
		
		if(reset = '0')then
			cuentaMuyMuyLento <= "1111010000100011111111111111111";
			finCuentaMuyMuyLento <= '0';
		elsif(clk'event and clk = '1') then
			if (cuentaMuyMuyLento /= "0000000000000000000000000000") then  
				cuentaMuyMuyLento <= cuentaMuyMuyLento - 1; 
			end if;		
		end if;
		if (pixelNaveVer = "1110111" and cuentaMuyMuyLento(30 downto 24) < "1011010") then  --recarga gasolina
			cuentaMuyMuyLento <= cuentaMuyMuyLento +20; 
		end if;
		if (teclaSPC = '1') then
			cuentaMuyMuyLento  <= "1111010000100011111111111111111";
		end if;						
	end process contadorMuyMuyLento;
	
	
	contVelVertical: process(reset,clk,cuentaVelVertical,finCuentaLento,teclaSPC,
								movNave,moverNave)  --contador mod 
	begin
		-- de 0 a 63, sube (para subir hay que restar)
		-- de 64 a 127, baja (para bajar hay que sumar)
		if(reset = '0')then
			cuentaVelVertical <= "1000110"; --70: cae a poca velocidad
		elsif(clk'event and clk = '1') then
			if  (finCuentaLento = '1' and moverNave = '1') then
				--127: con el bit mas sig, si es 0 el resto de bits seran la vel de caida; lo mismo para la de subida cuando bit mas sig igual 1	
				--hay gravedad:
				if (cuentaVelVertical < "1111101") then --125
					cuentaVelVertical <= cuentaVelVertical +2;
				end if;
				--si usamos los motores, cambiamos la velocidad
				if (movNave = "001") then --nave hacia arriba
					if (cuentaVelVertical >= "0000100") then --4
						cuentaVelVertical <= cuentaVelVertical - 4; 
					end if;
				end if;
			end if;
		end if;
		--generacion de velocidad			
		muyLentoVertical <= '0';
		lentoVertical <= '0';
		rapidoVertical <= '0';
		muyRapidoVertical <= '0';
		if ((cuentaVelVertical >= 0 and cuentaVelVertical < 15) or --subiendo muy rapido
			(cuentaVelVertical >= 109 and cuentaVelVertical <= 127)) then  --bajando muy rapido
			muyRapidoVertical <= '1';
		elsif ((cuentaVelVertical >=15 and cuentaVelVertical < 30) or --subiendo rapido
			(cuentaVelVertical >= 94 and cuentaVelVertical < 109)) then  --bajando rapido
			rapidoVertical <= '1';
		elsif ((cuentaVelVertical >= 30 and cuentaVelVertical < 45) or --subiendo lento
			(cuentaVelVertical >= 79 and cuentaVelVertical < 94)) then  --bajando lento
			lentoVertical <= '1';
		elsif ((cuentaVelVertical >= 45 and cuentaVelVertical < 64) or --subiendo muy lento
			(cuentaVelVertical >= 64 and cuentaVelVertical <= 79)) then  --bajando muy lento
			muyLentoVertical <= '1';
		end if;
		if (teclaSPC = '1') then
			cuentaVelVertical <= "1000110"; --70: cae a poca velocidad
		end if;	
	end process contVelVertical;
	
	
	contVelHorizontal: process(reset,clk,cuentaVelHorizontal,finCuentaLento,teclaSPC,
								movNave,moverNave)  --contador mod 
	begin
		-- de 0 a 63, izquierda (para ir izquierda hay que restar)
		-- de 64 a 127, derecha (para ir derecha hay que sumar)
		if(reset = '0')then
			cuentaVelHorizontal <= "1000110"; --70: cae a poca velocidad
		elsif(clk'event and clk = '1') then
			if (finCuentaLento = '1' and moverNave = '1') then
				--127: con el bit mas sig, si es 0 el resto de bits seran la vel de izquiera; lo mismo para la derecha cuando bit mas sig igual 1
				--si usamos los motores, cambiamos la velocidad
				if (movNave = "100") then --nave hacia derecha
					if (cuentaVelHorizontal < "1111011") then --123
						cuentaVelHorizontal <= cuentaVelHorizontal + 4; 
					end if;
				elsif (movNave = "011")	then --nave hacia la izquierda
					if (cuentaVelHorizontal >= "0000100") then --4
						cuentaVelHorizontal <= cuentaVelHorizontal - 4; 
					end if;
				end if;
			end if;
		end if;
		--generacion de velocidad			
		muyLentoHorizontal <= '0';
		lentoHorizontal <= '0';
		rapidoHorizontal <= '0';
		muyRapidoHorizontal <= '0';
		if ((cuentaVelHorizontal >= 0 and cuentaVelHorizontal < 15) or --izq muy rapido
			(cuentaVelHorizontal >= 109 and cuentaVelHorizontal <= 127)) then  --der muy rapido
			muyRapidoHorizontal <= '1';
		elsif ((cuentaVelHorizontal >=15 and cuentaVelHorizontal < 30) or --izq rapido
			(cuentaVelHorizontal >= 94 and cuentaVelHorizontal < 109)) then  --der rapido
			rapidoHorizontal <= '1';
		elsif ((cuentaVelHorizontal >= 30 and cuentaVelHorizontal < 45) or --izq lento
			(cuentaVelHorizontal >= 79 and cuentaVelHorizontal < 94)) then  --der lento
			lentoHorizontal <= '1';
		elsif ((cuentaVelHorizontal >= 45 and cuentaVelHorizontal < 64) or --izq muy lento
			(cuentaVelHorizontal >= 64 and cuentaVelHorizontal <= 79)) then  --der muy lento
			muyLentoHorizontal <= '1';
		end if;	
		if (teclaSPC = '1') then
			cuentaVelHorizontal <= "1000110"; --70: cae a poca velocidad
		end if;
	end process contVelHorizontal;
	
	
	
	
	nave: process(clk,reset,moverNave,finCuentaLento,pixelNaveHor,pixelNaveVer,movNave,
					  cuentaVelVertical,cuentaVelHorizontal,muyLentoHorizontal,
					  lentoHorizontal,rapidoHorizontal,muyRapidoHorizontal,muyLentoVertical,
					  lentoVertical,rapidoVertical,muyRapidoVertical)
	begin
		posNave(14 downto 7) <= pixelNaveHor;
		posNave(6 downto 0) <= pixelNaveVer;
	
		--vertical: cont mod 102 y horizontal: cont mod 153 
		if (reset = '0')then   --pos inicial coche1
			pixelNaveVer <= "0001000";  --en 9
			pixelNaveHor <= "00000011";  --en 3
		elsif (clk'event and clk = '1' and moverNave = '1') then
			
			--movimiento de la nave vertical
			if (cuentaVelVertical < "1000000") then --64 limite: va hacia arriba
				if (pixelNaveVer >= "0000001") then 
					if (muyLentoVertical = '1') then
						if (finCuentaMuyLento = '1') then 
							if (pixelNaveVer-1 /= "0000000") then pixelNaveVer <= pixelNaveVer - 1;	end if;
						end if;
					elsif (lentoVertical = '1') then
						if (finCuentaLento = '1') then 
							if (pixelNaveVer-1 /= "0000000") then pixelNaveVer <= pixelNaveVer - 1;	end if;
						end if;
					elsif (rapidoVertical = '1') then
						if (finCuentaRapido = '1') then 
							if (pixelNaveVer-1 /= "0000000") then pixelNaveVer <= pixelNaveVer - 1;	end if; 
						end if;
					elsif (muyRapidoVertical = '1') then
						if (finCuentaMuyRapido = '1') then 
							if (pixelNaveVer-1 /= "0000000") then pixelNaveVer <= pixelNaveVer - 1;	end if;
						end if;
					end if;
				end if;
			elsif (cuentaVelVertical >= "1000000") then --va hacia abajo
				if (pixelNaveVer < "1110111") then
					if (muyLentoVertical = '1') then
						if (finCuentaMuyLento = '1') then 
							if (pixelNaveVer-1 /= "1110111") then pixelNaveVer <= pixelNaveVer + 1;	end if;
						end if;
					elsif (lentoVertical = '1') then
						if (finCuentaLento = '1') then 
							if (pixelNaveVer-1 /= "1110111") then pixelNaveVer <= pixelNaveVer + 1;	end if; 
						end if;
					elsif (rapidoVertical = '1') then
						if (finCuentaRapido = '1') then
							if (pixelNaveVer-1 /= "1110111") then pixelNaveVer <= pixelNaveVer + 1;	end if;
						end if;
					elsif (muyRapidoVertical = '1') then
						if (finCuentaMuyRapido = '1') then 
							if (pixelNaveVer-1 /= "1110111") then pixelNaveVer <= pixelNaveVer + 1;	end if;
						end if;
					end if;
				end if;
			end if;	
			
			--movimiento de la nave horizontal
			if (cuentaVelHorizontal <"1000000") then --va hacia la izq
				if (muyLentoHorizontal = '1') then
					if (finCuentaMuyLento = '1') then 
						if (pixelNaveHor-1 /= "00000000") then pixelNaveHor <= pixelNaveHor - 1;	end if;
					end if;
				elsif (lentoHorizontal = '1') then
					if (finCuentaLento = '1') then
						if (pixelNaveHor-1 /= "00000000") then pixelNaveHor <= pixelNaveHor - 1;	end if;
					end if;
				elsif (rapidoHorizontal = '1') then
					if (finCuentaRapido = '1') then 
						if (pixelNaveHor-1 /= "00000000") then pixelNaveHor <= pixelNaveHor - 1;	end if;
					end if;
				elsif (muyRapidoHorizontal = '1') then
					if (finCuentaMuyRapido = '1') then
						if (pixelNaveHor-1 /= "00000000") then pixelNaveHor <= pixelNaveHor - 1;	end if;
					end if;
				end if;
			elsif (cuentaVelHorizontal >= "1000000") then --va hacia la der
				if (muyLentoHorizontal = '1') then
					if (finCuentaMuyLento = '1') then 
						if (pixelNaveHor-1 /= "10011000") then pixelNaveHor <= pixelNaveHor + 1;	end if;
					end if;
				elsif (lentoHorizontal = '1') then
					if (finCuentaLento = '1') then 
						if (pixelNaveHor-1 /= "10011000") then pixelNaveHor <= pixelNaveHor + 1;	end if;
					end if;
				elsif (rapidoHorizontal = '1') then
					if (finCuentaRapido = '1') then 
						if (pixelNaveHor-1 /= "10011000") then pixelNaveHor <= pixelNaveHor + 1;	end if;
					end if;
				elsif (muyRapidoHorizontal = '1') then
					if (finCuentaMuyRapido = '1') then 
						if (pixelNaveHor-1 /= "10011000") then pixelNaveHor <= pixelNaveHor + 1;	end if;
					end if;
				end if;
			end if;	
			if (teclaSPC = '1') then
				pixelNaveVer <= "0001000";  --en 9
				pixelNaveHor <= "00000011";  --en 3
			end if;
		end if;				
	end process nave;
	
	
	asigMovNave: process(teclaA,teclaW,teclaS,teclaD,cuentaMuyMuyLento)
	begin
		movNave <= "000";
		if (cuentaMuyMuyLento(30 downto 24) /= "0000000") then --si queda gasolina, enciendes motores
			if (teclaW = '1') then movNave <= "001";
			elsif (teclaS = '1') then movNave <= "010";
			elsif (teclaA = '1') then movNave <= "011";
			elsif (teclaD = '1') then movNave <= "100";
			else movNave <= "000";
			end if;
		end if;
	end process	asigMovNave;	
	
	
	generacionMundo: process(reset,clk,Q,pixelMundoVer,pixelMundoHor,enableContMundo)
	begin
		if (pixelMundoHor = "10011000") then --152:10011000 
			finCuentaContMundoHor <= '1';
		else 
			finCuentaContMundoHor <= '0';
		end if;
		
		if (reset = '0') then
			pixelMundoVer <= "1011010"; --90 
			pixelAnteriorVer <= "1011010"; --90 
			pixelMundoHor <= "00000000";
			finCuentaContMundoHor <= '0';
			pixelAleatorio <= '0';
			
		elsif (clk'event and clk = '1') then
			if(enableContMundo = '1' and finCuentaContMundoHor = '0') then 
				
				--sube y baja aleatoriamente dependiendo de unos valores fijados
				-- 0 <= Q <= 32767 (num de pixeles fisicos) 	1/4 = 8191    2/4 = 16383    3/4 = 24573
					if ((pixelMundoHor >= regBaseDificil1 and pixelMundoHor < regBaseDificil1 +5) or
						 (pixelMundoHor >= regBaseDificil2 and pixelMundoHor < regBaseDificil2 +5) or
						 (pixelMundoHor >= regBaseFacil and pixelMundoHor < regBaseFacil +9    ) ) then
						pixelMundoVer <= pixelMundoVer;					
					elsif (Q>=0 and Q <= 8191) then 
						pixelMundoVer <= pixelMundoVer - 2; 
						if (pixelMundoVer <= "0100111") then pixelMundoVer <= "0100111"; end if; --0100111=pixel logico 39 (el mundo no podrá subir más alla del tercio de la pantalla, para que entre la nave) 
					elsif (Q>8191 and Q <= 16383) then 
						pixelMundoVer <= pixelMundoVer - 1; 
						if (pixelMundoVer <= "0100111") then pixelMundoVer <= "0100111"; end if; --0100111=pixel logico 39				
					elsif (Q>16383 and Q <= 24573) then 
						pixelMundoVer <= pixelMundoVer + 2;  
						if (pixelMundoVer >= "1101110") then pixelMundoVer <= "1101110"; end if; --1101110=pixel logico 110 (el mundo no podrá bajar más alla del pixel 110 de la pantalla, para que se vea) 
					elsif (Q>24573 and Q <= 32767) then 
						pixelMundoVer <= pixelMundoVer + 1;  
						if (pixelMundoVer >= "1101110") then pixelMundoVer <= "1101110"; end if; --1101110=pixel logico 110
					end if;
					pixelMundoHor <= pixelMundoHor + 1;				
				
--				if (pixelMundoVer = "1110111") then --la columna ya estaba pintada, pixelMundoVer= 119
--					pixelMundoHor <= pixelMundoHor + 1;
--					--GENERACION SIGUIENTE PIXEL
--					pixelMundoVer <= Q(6 downto 0);
--				else
--					pixelMundoVer <= pixelMundoVer +1;
--				end if;	
				
			elsif (enableContMundo = '0') then
				pixelMundoVer <= "1011010"; --90
				pixelMundoHor <= "00000000";
			end if;
		end if;	
	end process generacionMundo;
	
	
	generacionBases: process(clk,reset,Q,contMod3,generarBases,clContMod3,selPixelMundo,
									 selPixelPantalla)
	begin
		if (reset = '0') then
--		regBaseDificil1 <= "0001111";
--		regBaseDificil2 <= "0110000";
--		regBaseFacil <= "0000100";
		
			regBaseDificil1 <= "0000000";
			regBaseDificil2 <= "0000000";
			regBaseFacil <= "0000000";
			contMod3 <= "00";
		elsif (clk'event and clk = '1') then
			if (generarBases = '1' and contMod3 /= "11") then
				case contMod3 is
					when "00" => regBaseDificil1 <= Q(6 downto 0); --7 bits porque 100="1100100". A la dir base de nuestras bases vamos a sumar un num aleatorio
					when "01" => regBaseDificil2 <= Q(6 downto 0);
					when "10" => regBaseFacil <= Q(6 downto 0);
					when others => null;
				end case;
				contMod3 <= contMod3 + 1;
			end if;
			if (clContMod3 = '1') then 
				contMod3 <= "00";
			end if;
		end if;				
	end process generacionBases;
	
	
	colision: process(DOAmundo,posNave,selPixelPantalla,pixelNaveHor,regBaseDificil1,
						regBaseDificil2,regBaseFacil)
	begin
		hayColision <= '0';  
		INhaAterrizado <= '0'; 
			
		if ((DOAmundo = "1" and posNave = selPixelPantalla) and not
			 ((pixelNaveHor >= regBaseDificil1 and pixelNaveHor < regBaseDificil1 +3) or --en base 3_1 
			  (pixelNaveHor >= regBaseDificil2 and pixelNaveHor < regBaseDificil2 +3) or --en base 3_2
			  (pixelNaveHor >= regBaseFacil and pixelNaveHor < regBaseFacil +7) --en base facil
			 )) then
			hayColision <= '1';
		end if;
 		if (DOAmundo = "1" and posNave = selPixelPantalla and
			 ((pixelNaveHor >= regBaseDificil1 and pixelNaveHor < regBaseDificil1 +3) or --en base 3_1 
			  (pixelNaveHor >= regBaseDificil2 and pixelNaveHor < regBaseDificil2 +3) or --en base 3_2
			  (pixelNaveHor >= regBaseFacil and pixelNaveHor < regBaseFacil +7) --en base facil
			 )) then
			INhaAterrizado <= '1';
		end if;
	end process colision; 


	biestable_D_haAterrizado: process(reset,clk,INhaAterrizado,movNave)   --con este biestableD conseguimos que continue el juego si ha aterrizado
	begin
		if(reset = '0')then 
			haAterrizado <= '0';
		elsif(clk'event and clk = '1' 
				--and (movNave = "001" or movNave = "010") --para solo dejar subir y bajar
				) then
			haAterrizado <=  INhaAterrizado;
		end if;	
	end process	biestable_D_haAterrizado;


--maquina de estados con registros de flags para el teclado---------------------

	controladorEstados: process (clk, reset, newData, scancode) 
	begin 
		if(reset = '0') then   
			estado <= pulsadas;
		elsif (clk'event and clk = '1') then
			estado <= pulsadas;  -- estado por defecto, puede ser sobreescrito luego
			case estado is
				when pulsadas => 
					estado <= pulsadas;
					if (newData = '1' and scancode = "11110000") then  --11110000: F0
						estado <= despulsadas;
					end if;
					
				when despulsadas =>
					estado <= despulsadas;
					if (newData = '1') then
						estado <= pulsadas;
					end if;					
			end case;
		end if;
	end process;


	generadorSalidaMealy: process (reset,newDataAck, scancode, estado, newData)
	begin
		newDataAck <= '0';
		clTeclaW <= '0';		
		clTeclaS <= '0';		
		clTeclaA <= '0';		
		clTeclaD <= '0';		
		clTeclaSPC <= '0';	
		ldTeclaW <= '0';		
		ldTeclaS <= '0';		
		ldTeclaA <= '0';		
		ldTeclaD <= '0';		
		ldTeclaSPC <= '0';	
		case estado is
			when pulsadas =>
				if (newData = '1') then  --11110000: F0
					case scancode is   	--registros de flags:
						when "00011101" => ldTeclaW <= '1';   clTeclaW <= '0'; 	  --W=1D
						when "00011011" => ldTeclaS <= '1';	  clTeclaS <= '0';	  --S=1B
						when "00011100" => ldTeclaA <= '1';	  clTeclaA <= '0';	  --A=1C 
						when "00100011" => ldTeclaD <= '1';	  clTeclaD <= '0';	  --D=23 
						when "00101001" => ldTeclaSPC <= '1'; clTeclaSPC <= '0';  --SPC=29 
						when others => null; 
					end case;
					newDataAck <= '1';
				end if;

			when despulsadas =>
				if (newData = '1') then
					case scancode is   	--registros de flags:
						when "00011101" => ldTeclaW <= '0';   clTeclaW <= '1'; 	  --W=1D 
						when "00011011" => ldTeclaS <= '0';	  clTeclaS <= '1';	  --S=1B
						when "00011100" => ldTeclaA <= '0';	  clTeclaA <= '1';	  --A=1C
						when "00100011" => ldTeclaD <= '0';	  clTeclaD <= '1';	  --D=23 
						when "00101001" => ldTeclaSPC <= '0'; clTeclaSPC <= '1';  --SPC=29 
						when others => null; 
					end case;
					newDataAck <= '1'; 
				end if;

			when others => null;	
		end case;
	end process;
	
	
	biestableDteclaSPC: process(reset,clk,ldTeclaSPC,clTeclaSPC)
	begin
		if(reset = '0')then 
			teclaSPC <= '0';
		elsif(clk'event and clk = '1' ) then
			if (clTeclaSPC = '1') then
				teclaSPC <=  '0';
			elsif (ldTeclaSPC = '1') then	
				teclaSPC <= '1';
			end if;
		end if;	
	end process	biestableDteclaSPC;
	
	
	biestableDteclaW: process(reset,clk,ldTeclaW,clTeclaW)
	begin
		if(reset = '0')then 
			teclaW <= '0';
		elsif(clk'event and clk = '1' ) then
			if (clTeclaW = '1') then
				teclaW <=  '0';
			elsif (ldTeclaW = '1') then	
				teclaW <= '1';
			end if;
		end if;	
	end process	biestableDteclaW;
	
	
	biestableDteclaS: process(reset,clk,ldTeclaS,clTeclaS)
	begin
		if(reset = '0')then 
			teclaS <= '0';
		elsif(clk'event and clk = '1' ) then
			if (clTeclaS = '1') then
				teclaS <=  '0';
			elsif (ldTeclaS = '1') then	
				teclaS <= '1';
			end if;
		end if;	
	end process	biestableDteclaS;
	
	
	biestableDteclaA: process(reset,clk,ldTeclaA,clTeclaA)
	begin
		if(reset = '0')then 
			teclaA <= '0';
		elsif(clk'event and clk = '1' ) then
			if (clTeclaA = '1') then
				teclaA <=  '0';
			elsif (ldTeclaA = '1') then	
				teclaA <= '1';
			end if;
		end if;	
	end process	biestableDteclaA;
	
	
	biestableDteclaD: process(reset,clk,ldTeclaD,clTeclaD)
	begin
		if(reset = '0')then 
			teclaD <= '0';
		elsif(clk'event and clk = '1' ) then
			if (clTeclaD = '1') then
				teclaD <=  '0';
			elsif (ldTeclaD = '1') then	
				teclaD <= '1';
			end if;
		end if;	
	end process	biestableDteclaD;
	

--maquina de estados del juego -------------------------------------------------

	controladorEstados2: process (clk, reset, finCuentaContMundoHor, finCuentaBarrido, 
									hayColision, teclaSPC) 
	begin 
		if(reset = '0') then   
			estado2 <= iniciando;
		elsif (clk'event and clk = '1') then
			estado2 <= iniciando;  -- estado por defecto, puede ser sobreescrito luego
			case estado2 is
				when iniciando =>
					estado2 <= iniciando;
					if (finCuentaContMundoHor = '1') then 
						estado2 <= jugando;
					end if;
			
				when jugando =>
					estado2 <= jugando;
					if (hayColision = '1') then 
						estado2 <= parado;
					end if;
					if (teclaSPC = '1') then 
						estado2 <= reseteo;
					end if;	
				
				when parado =>
					estado2 <= parado;
					if (teclaSPC = '1') then 
						estado2 <= reseteo;
					end if;	

				when reseteo => 
					estado2 <= reseteo;
					if (finCuentaBarrido = '1') then  
						estado2 <= iniciando;
					end if;					
			end case;
		end if;
	end process;

	
	generadorSalidaMoore2: process (estado2) 
	begin
		--memorias
		senialWEA <= '0';
		senialWEB <= '0';
		DIB <= "1";
		enableContBarrido <= '0';
		--juego:generar
		clContMod3 <= '1';
		enableContMundo <= '0';
		generarBases <= '0';
		--juego:estado
		moverNave <= '0';
		st <= "000";
		

		case estado2 is
			when iniciando =>	
				-- escribo por puerto B	
				--memorias
				senialWEA <= '0';
				senialWEB <= '1'; 
				DIB <= "1";
				enableContBarrido <= '0'; 
				--juego:generar
				clContMod3 <= '0';
				enableContMundo <= '1'; 
				generarBases <= '1';
				--juego:estado
				moverNave <= '0';
				st <= "000";
		
			when jugando =>
				-- leo por puerto A, escribo por puerto B
				--memorias
				senialWEA <= '0';
				senialWEB <= '0'; 
				DIB <= "0";
				enableContBarrido <= '0';--resetea contBarrido
				--juego:generar
				clContMod3 <= '0';
				enableContMundo <= '0';
				generarBases <= '0';
				--juego:estado
				moverNave <= '1';
				st <= "001";
		
			when parado =>								
				--memorias
				senialWEA <= '0';
				senialWEB <= '0'; 
				DIB <= "0";
				enableContBarrido <= '0'; --resetea contBarrido
				--juego:generar
				clContMod3 <= '0'; --no se toca, se necesitan los reg para calcular colisiones
				enableContMundo <= '0';
				generarBases <= '0';
				--juego:estado
				moverNave <= '0';
				st <= "010";
				
			when reseteo =>
				-- reseteo por puerto A
				--memorias
				senialWEA <= '1';
				senialWEB <= '0'; 
				DIB <= "0";
				enableContBarrido <= '1';
				--juego:generar
				clContMod3 <= '1'; --para que en iniciando se vuelvan a generar las bases
				enableContMundo <= '0';
				generarBases <= '0';
				--juego:estado
				moverNave <= '0';
				st <= "011";
			
			when others => null;	
		end case;
	end process;
	
	
	conversor7seg: process(st)
	begin
		case st is
								      --gfedcba
			when "000" => segs <= "0111111";  
			when "001" => segs <= "0000110"; 
			when "010" => segs <= "1011011"; 
			when "011" => segs <= "1001111"; 
			when OTHERS => segs <= "1111001";  -- error
			end case;
	end process;
	
	
--------------------------------------------------------------------------------
	
	--contador para limpiar la ram
	contBarrido: process(reset,clk,cuentaContBarrido,enableContBarrido)  --contador mod 2^15=32768	(120 x 153 pixeles)
	begin
		if (cuentaContBarrido = "111111111111111") then 
			finCuentaBarrido <= '1';
		else
			finCuentaBarrido <= '0';
		end if;
		
		if(reset = '0')then
			cuentaContBarrido <= (others => '0');
			finCuentaBarrido <= '0';
		elsif(clk'event and clk = '1') then 
			if(enableContBarrido = '1') then
				if (cuentaContBarrido /= "111111111111111") then  
					cuentaContBarrido <= cuentaContBarrido + 1; 
				end if;
			elsif (enableContBarrido = '0') then
				cuentaContBarrido <= (others => '0');
			end if;
		end if;
	end process contBarrido;
	
	
	
--------------------------------------------------------------------------------

	-- lsfr para la generacion aleatoria
	lsfr: process(reset,clk,D,Q)
	begin
		--conexiones entre biestables
		D(14 downto 1) <= Q(13 downto 0);  --D(X) es Q(X-1)
		--entrada de D1
		puertaAND <= (Q(14 downto 14) and Q(13 downto 13) and Q(12 downto 12) and 
						  Q(11 downto 11) and Q(10 downto 10) and Q(9 downto 9) and 
						  Q(8 downto 8) and Q(7 downto 7) and Q(6 downto 6) and 
						  Q(5 downto 5) and Q(4 downto 4) and Q(3 downto 3) and 
						  Q(2 downto 2) and Q(1 downto 1) and Q(0 downto 0));
		D(0 downto 0) <= ( (not (Q(14 downto 14) xor Q(13 downto 13)))
								 xor (puertaAND or puertaAND) );
		
	   if(reset = '0')then 
			Q(14 downto 0) <= (others => '0');
		elsif(clk'event and clk = '1' ) then
			Q <= D;
		end if;	
	end process lsfr;
	


end Behavioral; 
