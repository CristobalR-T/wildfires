/* descriptivePlots.do           damiancclarke             yyyy-mm-dd:2023-04-11
----|----1----|----2----|----3----|----4----|----5----|----6----|----7----|----8
  Make descriptive plots on fires

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
cap mkdir "$LOG"
log using "$LOG/descriptivePlots.txt", text replace

*-------------------------------------------------------------------------------
*--- (1) Descriptives on fire sizes and fire duration
*-------------------------------------------------------------------------------
cd "$DAT/fires"
local afiles
foreach yr of numlist 2002(1)2021 {
    dis "`yr'"
    local yrplus1 = `yr'+1
    unzipfile "I_`yr'-`yrplus1'"
    use "$DAT/fires/I_`yr'-`yrplus1'.dta", clear
    bys ID: gen n=_n
    qui keep if n==1
    foreach var of varlist Inicio Extinc {
        qui replace `var' = subinstr(`var', "abr", "apr", 1)
        qui replace `var' = subinstr(`var', "ago", "aug", 1)
        qui replace `var' = subinstr(`var', "dic", "dec", 1)
        qui replace `var' = subinstr(`var', "ene", "jan", 1)
    }
    qui gen double startD = clock(Inicio, "DMYhm")
    qui gen double endedD = clock(Extinc, "DMYhm")
    qui gen double duration = (endedD-startD)/(60*60*1000*24)

    drop if duration<0
    split Inicio
    rename Inicio1 beginDate
    split beginDate, parse("-")
    rename beginDate3 beginYear
    drop Inicio2 beginDate*
                     
    rm "I_`yr'-`yrplus1'.dta"
    tempfile tf`yr'
    save `tf`yr''
    local afiles `afiles' `tf`yr''
}

clear
append using `afiles', force

foreach num of numlist 0(50)250 500 {
    gen HA`num' = Superficie>`num'
}



colorpalette viridis, n(4) nograph
local color1 = r(p1)
local color3 = r(p3)



destring beginYear, replace
drop if beginYear<2004
local hopts color("`color1'") xtitle("Total area burned (ha)") freq
hist Super if Super<10, `hopts' ylabel(, format(%9.0gc))
graph export "$OUT/firesHA0_10.eps", replace
hist Super if Super>=10&Super<100, `hopts' xlabel(10(10)100)
graph export "$OUT/firesHA10_100.eps", replace
hist Super if Super>=100&Super<500, `hopts'
graph export "$OUT/firesHA100_500.eps", replace
hist Super if Super>=500&Super<1000, `hopts'
graph export "$OUT/firesHA500_1000.eps", replace


colorpalette viridis, n(4) nograph
local color1 = r(p1)
local color3 = r(p3)
gen hours = duration
local hopts color("`color3'") xtitle("Total duration (hours)")  freq
hist hours if hours<3,`hopts' ylabel(, format(%9.0gc)) 
graph export "$OUT/firesHours0_3.eps", replace
hist hours if hours>=3&hours<24, `hopts' xlabel(3(3)24)
graph export "$OUT/firesHours3_24.eps", replace 
hist hours if hours>=24&hours<72, `hopts' xlabel(24(8)72) 
graph export "$OUT/firesHours24_72.eps", replace
hist hours if hours>=72&hours<336, `hopts' xlabel(72(24)336) 
graph export "$OUT/firesHours72_336.eps", replace

exit
*-------------------------------------------------------------------------------
*--- (2) Descriptives on fire sizes over time
*-------------------------------------------------------------------------------
preserve
collapse (sum) HA*, by(beginYear)
colorpalette viridis, n(7) nograph
foreach n of numlist 1(1)7 {
    local c`n' = r(p`n')
}
keep if beginYear>=2003
#delimit ;
twoway connected HA0   beginYear, lcolor(`"`c1'"')
||     connected HA50  beginYear, lcolor(`"`c2'"')
||     connected HA100 beginYear, lcolor(`"`c3'"')
||     connected HA150 beginYear, lcolor(`"`c4'"')
||     connected HA200 beginYear, lcolor(`"`c5'"')
||     connected HA250 beginYear, lcolor(`"`c6'"')
||     connected HA500 beginYear, lcolor(`"`c7'"')
legend(order(1 "> 0 HA" 2 "> 50 HA" 3 "> 100 HA" 4 "> 150 HA"
             5 "> 200 HA" 6 "> 250 HA" 7 "> 500 HA"));
#delimit cr
graph export "$OUT/fireSizes.pdf", replace
restore
