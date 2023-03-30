/* analysisMP25.do               damiancclarke             yyyy-mm-dd:2023-02-20
----|----1----|----2----|----3----|----4----|----5----|----6----|----7----|----8

  Script to analyse impact of fires on MP 2.5. 

*/

vers 14
clear all
set more off
cap log close


*-------------------------------------------------------------------------------
*--- (0) Globals and locals
*-------------------------------------------------------------------------------
global ROOT "~/investigacion/2022/climateChangeLatAm/replication"

global DAT "{$ROOT}/data"
global OUT "{$ROOT}/results"
global LOG "{$ROOT}/log"

log using "$LOG/analysisMP25.txt", text replace
cap mkdir "$OUT/figures"

*-------------------------------------------------------------------------------
*--- (1) Match fires with MP 2.5
*-------------------------------------------------------------------------------
/*     
local files
foreach yr of numlist 2003(1)2021 {
    use "$DAT/PM25/Municipio_pm2p5_`yr'", clear
    split Date
    collapse pm2p5, by(Date1)
    gen date = date(Date1, "YMD")
    keep date pm2p5
    tempfile yr`yr'
    save `yr`yr''
    local files `files' `yr`yr''
}
clear
append using `files'
format date %td
twoway line pm2p5 date, lcolor(blue%50) ytitle("Mean PM 2.5 (kg/m{sup:3})") xtitle("Date")
graph export "$OUT/descriptives/pm25time.pdf", replace
*/


local files
foreach year of numlist 2004(1)2021 {
    dis "Year is `year'"
    use "$DAT/PM25/Municipio_pm2p5_`year'.dta", clear
    decode CUT_2018, gen(Cod_Comuna_2018)
    *gen Cod_Comuna_2018 = string(CUT_2018, "%05.0f")
    foreach dist of numlist 0(25)200 250 500 {
        merge 1:1 Date Cod_Comuna_2018 using "$DAT/windAndFires/fireWind_`year'_`dist'_donut5.dta"
        foreach type in upwind downwind nondownwind {
            *`type'Duration  `type'Surface 
            foreach var of varlist `type' `type'Distance {
                rename `var' `var'_`dist' 
            }
        }
        foreach var of varlist F_exposure_0_45 F_exposure_45_90 F_exposure_90_135 F_exposure_135_180 {
            rename `var' `var'_`dist'
        }
        sum upwind_`dist' downwind_`dist' nondownwind_`dist' fire
        keep pm2p5 Date Cod_Comuna_2018 CUT_2018 upwind* downwind* nondownwind* windSpeed F_exposure*
    }
    tempfile firemp`year'
    save `firemp`year''
    local files `files' `firemp`year''
}
clear
append using `files'

sum windSpeed

foreach dist of numlist 0(25)200 250 {
    replace upwind_`dist'   = 0 if upwind_`dist'==.
    replace downwind_`dist' = 0 if downwind_`dist'==.
    replace nondownwind_`dist' = 0 if nondownwind_`dist'==.
    foreach var in F_exposure_0_45 F_exposure_45_90 F_exposure_90_135 F_exposure_135_180 {
        replace `var'_`dist' = 0 if `var'_`dist'==.
    }
}

destring Cod_Comuna_2018, replace
gen region = floor(Cod_Comuna_2018/1000)
bys CUT_2018 (Date): gen time = _n


gen LB_up     = .
gen UB_up     = .
gen Beta_up   = .
gen LB_down   = .
gen UB_down   = .
gen Beta_down = .
gen distance  = .
gen equality  = .

local j=1
sum windSpeed, d
local median = r(p50)
local opts absorb(time CUT_2018) cluster(CUT_2018)
foreach dist of numlist 0(25)200 250 {
    reghdfe pm2p5 upwind_`dist' downwind_`dist' nondownwind_`dist', `opts'
    replace Beta_up = _b[upwind_`dist'] in `j'
    replace LB_up   = _b[upwind_`dist']+invnormal(0.025)*_se[upwind_`dist'] in `j'
    replace UB_up   = _b[upwind_`dist']+invnormal(0.975)*_se[upwind_`dist'] in `j'

    replace Beta_down = _b[downwind_`dist'] in `j'
    replace LB_down   = _b[downwind_`dist']+invnormal(0.025)*_se[downwind_`dist'] in `j'
    replace UB_down   = _b[downwind_`dist']+invnormal(0.975)*_se[downwind_`dist'] in `j'
    test upwind_`dist'= downwind_`dist'
    replace equality = r(p) in `j'

    replace distance = `dist' in `j'
    local ++j
}
#delimit ;
twoway rarea LB_up UB_up distance, color(gs10%30)
   || line Beta_up distance, lcolor(red) lwidth(medthick) lpattern(solid)
   || rarea LB_down UB_down distance, color(gs10%30)
   || line Beta_down distance, lcolor(blue) lwidth(medthick) lpattern(dash)
ytitle("MP 2.5 (kg/m{sup:3})") xtitle("Fire Size (Ha)")
legend(order(2 "Estimate (upwind)" 4 "Estimate (downwind)" 1 "95% CI") position(6) rows(1))
yline(0, lpattern(dash));
#delimit cr
graph export "$OUT/figures/exposurePM25.pdf", replace
drop LB_* UB_* Beta_* distance equality






