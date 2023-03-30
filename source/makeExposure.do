/* makeExposure.do              damiancclarke              yyyy-mm-dd:2022-01-25
----|----1----|----2----|----3----|----4----|----5----|----6----|----7----|----8

Makes exposure to fires at municipality by day level. This takes two data inputs
 > xxxx-yyyy_120KMCC.dta: xxxx and yyyy are two subsequent years, and this lists
   all forest fires and comunas within 120 KM of fires (multiple lines per fire)
 > u10_v10_xxxx: xxxx is a year.  This lists wind directions and velocities in a
   standardized way from satellite data at municipal centroids, in 3 hour blocks

This do file aims to make a systematic database where for each municipality in 
each day we have information on whether it is exposed to any fire, and if so, w-
hether it is downwind (wind taking smoke towards the comuna) or downwind (wind 
not taking smoke towards the comuna) from the fire.

To do this, it is necessary first to expand all fires and municipalities exposed
by their length of exposure, ie if a fire lasts 3 days, ensure that we have wind
directions for the full three days (this is done in 3 hour blocks initially). T-
hen this is collapsed at a comuna by day level.  Note that in this process, fir-
es starting in year 2002 will spill over into year 2003 given that some will st-
ill be burning, and as such, fires need to be followed over years. This is cond-
ucted in the code below.



**NOTE THAT TO GENERATE comunaBase, this is simply one line per comuna. Made as:
import excel using "$DAT/crosswalk.xlsx", firstrow
bys Nom_Comuna: gen n=_n
keep if n==1
drop Mes Año n
save "$DAT/comunaBase.dta", replace

Key parameters that are set below are:
 > delta: The angle at which fires intersects municipalities such that they are
          considered close enough to be exposed (+/- delta)
 > firesize: Different sizes of fires generated in outcome exposure data sets.
             This defines minimum fire sizes to be considered (multiple values)

 > donut: Defines the size of the "donuts" which we consider which remove
          observations directly exposed if within x km of a fire (0 is no donut,
          5 is 5km, etc.)

All of these can be controlled in section 0 of the code.


*/

vers 15
clear all
set more off
cap log close

*-------------------------------------------------------------------------------
*--- (0) General globals and key parameters
*-------------------------------------------------------------------------------
if c(username)=="damian" {
    global BASE "/home/damian/investigacion/2022/climateChangeLatAm/replication"
}


global DAT "${BASE}/data"
global LOG "${BASE}/log"
global OUT "${BASE}/results/descriptives"

cap mkdir "${BASE}/results"
cap mkdir $LOG
cap mkdir $OUT
cap mkdir "$DAT/windAndFires"
cap mkdir "$DAT/exposure"

log using "$LOG/makeExposure.txt", text replace


local delta = 30
local firesize 25 50 75 100 125 150 175 200 250 500 0 
local donuts 0 5

foreach donut of numlist `donuts' {
    foreach farea of numlist `firesize' {        
        dis "Fire area is `farea'"
        
        *-----------------------------------------------------------------------
        *--- (1) Set up municipal by day panel [LEAP YEAR 2000(4)2020]
        *-----------------------------------------------------------------------
        if `farea'==0 {     
            **2002
            use "${DAT}/fires/I_2002-2003"
            rename CUT_2018 numeric_CUT_2018
            gen CUT_2018 = string(numeric_CUT_2018,"%05.0f")
            keep if LENGTH_KM>=`donut'
            keep if Superficie>=`farea' & Superficie!=.
            
            drop beta_radia*
            rename Lat CONAF_Lat
            rename Lon CONAF_Lon
            
            split Inicio
            rename Inicio1 beginDate
            rename Inicio2 beginHour
            split beginHour, parse(":")
            rename beginHour1 hourRound
            destring hourRound, replace
            drop beginHour2
            split beginDate, parse("-")
            rename beginDate1 beginDay
            rename beginDate2 beginMonth
            rename beginDate3 beginYear
            destring beginDay, replace
            destring beginYear, replace
            
            tab beginYear
            keep if beginYear==2002
            
            foreach var of varlist Inicio Extinc {
                replace `var' = subinstr(`var', "abr", "apr", 1)
                replace `var' = subinstr(`var', "ago", "aug", 1)
                replace `var' = subinstr(`var', "dic", "dec", 1)
                replace `var' = subinstr(`var', "ene", "jan", 1)
            }
            gen double startD = clock(Inicio, "DMYhm")
            gen double endedD = clock(Extinc, "DMYhm")
            gen double duration = (endedD-startD)/(60*60*1000)
            
            gen beginBlock = floor(hourRound/3)*3
            gen expander   = ceil(duration/3)
            
            gen fireMunID = _n
            
            replace expander = 1 if expander==0
            expand expander
            
            bys fireMunID: gen hourDelta=3*(_n-1)
            
            gen double timeTracker = startD + hourDelta*60*60*1000
            
            gen DAY = day(dofc(timeTracker))
            gen MON = month(dofc(timeTracker))
            gen YEA = year(dofc(timeTracker))
            gen HOU = hh(timeTracker)
            gen HOU_R = floor(HOU/3)*3
            
            gen str4 D1 = string(YEA)
            gen str2 D2 = string(MON,"%02.0f")
            gen str2 D3 = string(DAY,"%02.0f")
            gen str2 D4 = string(HOU_R,"%02.0f")
            
            gen Date = D1 + "-" + D2 + "-" + D3 + " " + D4 + ":00:00"
            rename Comuna Nom_Comuna
            replace Nom_Comuna = "Los Álamos"  if Nom_Comuna=="Los Alamos"
            replace Nom_Comuna = "Los Ángeles" if Nom_Comuna=="Los Angeles"
            replace Nom_Comuna = "Marchihue"   if Nom_Comuna=="Marchigue"
            replace Nom_Comuna = "Puchuncaví"  if Nom_Comuna=="Puchuncavi"
            
            merge m:1 Nom_Comuna using "$DAT/comunaBase"
            drop if _merge==2
            drop _merge
            
            rename CUT_2018 CUT_2018_exposure
            rename Cod_Comuna_2018 CUT_2018
            **THIS IS A KLUDGE -- fix in arcgis -- FIXED NOW.  THIS CONDITION NEVER OCCURS
            tostring CUT_2018_exposure, replace //for new data
            replace CUT_2018 = CUT_2018_exposure if CUT_2018==""
            
            **strip out preceding zeros
            destring CUT_2018, replace
            tostring CUT_2018, replace
            
            *merge m:1 CUT_2018 Date using "${DAT}/Vientos u 10y v10/u10_v10_2002"
            merge m:1 CUT_2018 Date using "${DAT}/fires/wind/u10_v10_2002"
            //drop observations if no fires in municipality*time cell
            drop if _merge==2
            keep if D1=="2003"
            drop _merge Long Lat viento_v10 Comuna viento_u10
        }
        else {
            clear
            set obs 0
            gen Superficie=.
        }
        tempfile overflow2003
        save `overflow2003'
        clear


        local dsum = 0
        foreach yr of numlist 2003(1)2021 {
            if mod(`yr',4)==0 {
                dis "Leap Year `yr'"
                local ndays = 366
            }
            else {
                dis "Year `yr'"
                local ndays = 365
            }
            use "$DAT/comunaBase", clear
            expand `ndays'
            bys Nom_Comuna: gen date = _n+15705+`dsum'
            format date %td

            tempfile year`yr'
            save `year`yr''

            *-------------------------------------------------------------------
            *--- (2) Work with fires for one year
            *---    make the file into 1 line per fire exposure per 3 hour block
            *-------------------------------------------------------------------
            local yrminus1 = `yr'-1
            local yrplus1  = `yr'+1
            use "${DAT}/fires/I_`yrminus1'-`yr'"
            
            dis "Count file `yrminus1'-`yr'"
            count
            drop beta_radia*
            append using "${DAT}/fires/I_`yr'-`yrplus1'", force
            keep if LENGTH_KM>=`donut'
            keep if Superficie>=`farea' & Superficie!=.
        
            rename CUT_2018 numeric_CUT_2018
            gen CUT_2018 = string(numeric_CUT_2018,"%05.0f")
            
            drop beta_radia*
            dis "Count file ``yr'-yrplus1'"
            count
            rename Lat CONAF_Lat
            rename Lon CONAF_Lon
            
            
            split Inicio
            rename Inicio1 beginDate
            rename Inicio2 beginHour
            split beginHour, parse(":")
            rename beginHour1 hourRound
            destring hourRound, replace
            drop beginHour2
            split beginDate, parse("-")
            rename beginDate1 beginDay
            rename beginDate2 beginMonth
            rename beginDate3 beginYear
            destring beginDay, replace
            destring beginYear, replace
        
            tab beginYear
            keep if beginYear==`yr'
            
            foreach var of varlist Inicio Extinc {
                replace `var' = subinstr(`var', "abr", "apr", 1)
                replace `var' = subinstr(`var', "ago", "aug", 1)
                replace `var' = subinstr(`var', "dic", "dec", 1)
                replace `var' = subinstr(`var', "ene", "jan", 1)
            }
            gen double startD = clock(Inicio, "DMYhm")
            gen double endedD = clock(Extinc, "DMYhm")
            gen double duration = (endedD-startD)/(60*60*1000)
            
            gen beginBlock = floor(hourRound/3)*3
            gen expander   = ceil(duration/3)
            
            gen fireMunID = _n
        
            replace expander = 1 if expander==0
            expand expander
            
            bys fireMunID: gen hourDelta=3*(_n-1)
            
            gen double timeTracker = startD + hourDelta*60*60*1000
        
            gen DAY = day(dofc(timeTracker))
            gen MON = month(dofc(timeTracker))
            gen YEA = year(dofc(timeTracker))
            gen HOU = hh(timeTracker)
            gen HOU_R = floor(HOU/3)*3
            
            gen str4 D1 = string(YEA)
            gen str2 D2 = string(MON,"%02.0f")
            gen str2 D3 = string(DAY,"%02.0f")
            gen str2 D4 = string(HOU_R,"%02.0f")
        
            gen Date = D1 + "-" + D2 + "-" + D3 + " " + D4 + ":00:00"
            rename Comuna Nom_Comuna
            replace Nom_Comuna = "Los Álamos"  if Nom_Comuna=="Los Alamos"
            replace Nom_Comuna = "Los Ángeles" if Nom_Comuna=="Los Angeles"
            replace Nom_Comuna = "Marchihue"   if Nom_Comuna=="Marchigue"
            replace Nom_Comuna = "Puchuncaví"  if Nom_Comuna=="Puchuncavi"
        
            dis "Merge fires to comuna details (using is 346 lines)"
            **Merge == 3 is fires occurring in municipalites
            **Merge == 2 is fires without municipality name assigned yet (to get from lat/long)
            **Merge == 1 is fires occurring after end of year
            merge m:1 Nom_Comuna using "$DAT/comunaBase"
            drop if _merge==2
            drop _merge
            
            rename CUT_2018 CUT_2018_exposure
            rename Cod_Comuna_2018 CUT_2018
            **THIS IS A KLUDGE -- fix in arcgis -- FIXED NOW.  THIS CONDITION NEVER OCCURS
            tostring CUT_2018_exposure, replace //for new data
            replace CUT_2018 = CUT_2018_exposure if CUT_2018==""
        
            **strip out preceding zeros
            destring CUT_2018, replace
            tostring CUT_2018, replace
        
            **Add previous year's overflow (fire that started year prior, but rolled over)
            append using `overflow`yr'', force
            drop Causa_gene-Subtotal_o
            drop Temperatur-Exposició
            drop FID direccion POINT_X_1 POINT_Y_1 X_muni Y_muni
            drop CONAF_Lat CONAF_Lon Topograf Pendiente betamas30 betamenos30
            drop DAY MON HOU HOU_R D2 D3 D4
            compress
            
            dis "Merge fires to wind information"
            **Merge == 3 is fires occurring in municipalities
            **Merge == 1 is fires occurring outside of year
            **Merge == 2 is municipalities with no fires
            merge m:1 CUT_2018 Date using "$DAT/wind/u10_v10_`yr'"
            //drop observations if no fires in municipality*time cell
            drop if _merge==2
        
            **TAKE FIRES THAT START IN CURRENT YEAR, BUT GO TO NEXT YEAR...
            preserve
            keep if D1=="`yrplus1'"
            drop _merge Long Lat viento_v10 Comuna viento_u10 
            tempfile overflow`yrplus1'
            save `overflow`yrplus1''
            restore
            drop if D1=="`yrplus1'"
        
            foreach var of varlist Long Lat viento* {
                destring `var', replace
            }
        
            rename beta_grado bearingComuna
        
            *gen bearingWind = atan2(viento_u10,viento_v10)*180/c(pi)
            gen bearingWind = atan2(viento_v10,viento_u10)*180/c(pi)
            replace bearingWind = bearingWind + 360 if bearingWind<0
            gen windSpeed = sqrt(viento_u10^2+viento_v10^2)
        
            
            gen windPlus  = bearingWind + `delta'
            replace windPlus = windPlus-360 if windPlus>360
            gen windMinus = bearingWind - `delta'
            replace windMinus = windMinus + 360 if windMinus<0
        
            ***FOR MAPS
            gen distancia = LENGTH_KM*1000
            preserve
            rename bearingComuna beta_grado
            keep CUT_2018_exposure Superficie la1 lo1 beta_grado Date duration distancia 
            rename CUT_2018_exposure CUT_2018
            rename distancia Distancia
            cap mkdir "$DAT/maps"
            save "$DAT/maps/fires`yr'", replace 
            restore
        
            **bearing difference calculates distance between wind direction
            **  and municipality direction
            #delimit ;
            gen bearingDifference = min(abs(bearingWind-bearingComuna),
                                    360-abs(bearingWind-bearingComuna));
            #delimit cr
            sum bearingDifference
            count
            gen fire        = 1
            gen upwind      = bearingDifference<=`delta'
            gen downwind    = bearingDifference>=(180-`delta') & bearingDifference!=.
            gen nondownwind = bearingDifference>`delta' & bearingDifference<(180-`delta')
        
            gen F_exposure_0_45    = bearingDifference>=0&bearingDifference<=45 
            gen F_exposure_45_90   = bearingDifference>45&bearingDifference<=90 
            gen F_exposure_90_135  = bearingDifference>90&bearingDifference<=135 
            gen F_exposure_135_180 = bearingDifference>135&bearingDifference<=180 
            
            foreach f in upwind downwind nondownwind {
                gen `f'Duration = duration   if `f'==1
                gen `f'Surface  = Superficie if `f'==1
                gen `f'Distance = distancia  if `f'==1
            }
            // GENERATE a municipality by time block dataset (groups multiple fires)
            // This is used for MP 2.5 analysis at high frequency
            #delimit ;
            collapse windSpeed upwindDistance downwindDistance nondownwindDistance
            (sum)    upwind downwind nondownwind fire F_exposure_*,
            by(NOM_COM CUT_2018_exposure Date);
            #delimit cr
            
            gen date = date(Date, "YMDhms") 
            rename CUT_2018_exposure Cod_Comuna_2018
            save "$DAT/windAndFires/fireWind_`yr'_`farea'_donut`donut'.dta", replace
        
            // GENERATE a municipality by day dataset (groups multiple fires)
            // This is then joined to empty cells so it is a balanced panel
            #delimit ;
            collapse windSpeed upwind downwind nondownwind 
            upwindDistance downwindDistance nondownwindDistance fire F_exposure_*,
            by(NOM_COM Cod_Comuna_2018 date);
            #delimit cr
            replace upwind      = ceil(upwind)
            replace nondownwind = ceil(nondownwind)
            replace downwind    = ceil(downwind)
            replace fire        = ceil(fire)
            
            dis "Merge fires by day to full municipality panel"
            **Merge == 2 is days with no fires
            **Merge == 3 is days with fires
            merge m:1 Cod_Comuna_2018 date using `year`yr''
            local dsum = `dsum'+`ndays'
            save "$DAT/comunaExposure_`yr'", replace    
            tab Cod_Comuna_2018
        }
        
        use "$DAT/comunaExposure_2003", clear
        rm "$DAT/comunaExposure_2003"
        foreach num of numlist 2004(1)2019 {
            append using "$DAT/comunaExposure_`num'"
            rm "$DAT/comunaExposure_`num'"
        }
        
        *-------------------------------------------------------------------------------
        *--- (3a) Generate weekly panel that corresponds to the exposure dates in health
        *-------------------------------------------------------------------------------
        save "$DAT/exposure/exposureDaily_`farea'ha_donut`donut'.dta", replace
        **This fixes the date with regards to 2001 when egresos starts
        gen accumDays    = date-14975
        gen weeksEgresos = ceil(accumDays/7)
        
        dis "collapse to week by municipality panel"
        #delimit ;
        collapse upwindDistance downwindDistance  nondownwindDistance windSpeed
                 (sum) upwind   downwind          nondownwind         fire
                 F_exposure_*,  by(weeksEgresos Cod_Comuna_2018);
        #delimit cr
        
        save "$DAT/exposure/exposureWeekly_egresos_`farea'ha_donut`donut'.dta", replace
        
        *-------------------------------------------------------------------------------
        *--- (3b) Generate weekly panel that corresponds to the exposure dates in birth
        *-------------------------------------------------------------------------------
        use "$DAT/exposure/exposureDaily_`farea'ha_donut`donut'.dta", replace
        **This fixes the date with regards to 1992 when births starts
        gen accumDays    = date-11687
        gen weeksBirths = ceil(accumDays/7)
        
        dis "collapse to week by municipality panel"
        #delimit ;
        collapse upwindDistance downwindDistance nondownwindDistance windSpeed
                 (sum) upwind   downwind         nondownwind         fire
                 F_exposure_*,  by(weeksBirths Cod_Comuna_2018);
        #delimit cr
        
        
        save "$DAT/exposure/exposureWeekly_births_`farea'ha_donut`donut'.dta", replace
        
        
        *-------------------------------------------------------------------------------
        *--- (3b) Generate weekly panel that corresponds to the exposure dates in death
        *-------------------------------------------------------------------------------
        use "$DAT/exposure/exposureDaily_`farea'ha_donut`donut'.dta", replace
        **This fixes the date with regards to 1990 when mortality starts
        gen accumDays    = date-10957
        gen weeksDeaths = ceil(accumDays/7)
        
        dis "collapse to week by municipality panel"
        #delimit ;
        collapse upwindDistance downwindDistance nondownwindDistance windSpeed
                 (sum) upwind   downwind         nondownwind         fire
                 F_exposure_*,  by(weeksDeaths Cod_Comuna_2018);
        #delimit cr
        
        
        save "$DAT/exposure/exposureWeekly_deaths_`farea'ha_donut`donut'.dta", replace
    }
}
