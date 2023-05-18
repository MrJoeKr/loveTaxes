globals
[
  max-grain    ; maximum amount any patch can hold
  num-grain-grown
  grain-growth-interval
  state-treasure ; total amount of state money
  poverty-fine   ; The amount state pays for poor agents each tick
  eat-price    ; price for eating is slider (constant)
  dead-people    ; number of agents who died
  starting-wealth ; starting wealth of turtles
  max-ticks-in-poverty ; how many turns in poverty before death
  dead-fine
  lower-class-harvest-amount
  upper-class-harvest-amount
]

patches-own
[
  grain-here      ; the current amount of grain on this patch
  max-grain-here  ; the maximum amount of grain this patch can hold
]

turtles-own
[
  wealth           ; the amount of grain a turtle has
  life-expectancy  ; maximum age that a turtle can reach
  vision           ; how many patches ahead a turtle can see
  class            ; what social class is in, based on wealth
                   ; 0.5 - lower (0-25%)
                   ; 1 - high (75-100%)
  ticks-in-poverty ; how many turns is turtle below eat-price
]

;;;
;;; SETUP AND HELPERS
;;;

to setup
  clear-all
  ;; set global variables to appropriate values
  set max-grain 100
  set grain-growth-interval 1
  ;; TO BE BALANCED
  set eat-price 0.9 ; 0.9 seems the best value
  set num-grain-grown 0.1 ; 0.1
  set lower-class-harvest-amount 15
  set upper-class-harvest-amount 30
  ;;;;;;;;;;;;;;;;;;;;;;;;;
  set state-treasure 0
  set poverty-fine 1
  set dead-people 0
  set starting-wealth 50 ; 20
  set max-ticks-in-poverty 10 ; 5
  set dead-fine 100
  ;; call other procedures to set up various parts of the world
  setup-patches
  setup-turtles
  reset-ticks
end

;; set up the initial amounts of grain each patch has
to setup-patches
  ;; give some patches the highest amount of grain possible --
  ;; these patches are the "best land"
  ask patches
    [ set max-grain-here 0
      if (random-float 100.0) <= percent-best-land
        [ set max-grain-here max-grain
          set grain-here max-grain-here ] ]
  ;; spread that grain around the window a little and put a little back
  ;; into the patches that are the "best land" found above
  repeat 5
    [ ask patches with [max-grain-here != 0]
        [ set grain-here max-grain-here ]
      diffuse grain-here 0.25 ]
  repeat 10
    [ diffuse grain-here 0.25 ]          ;; spread the grain around some more
  ask patches
    [ set grain-here floor grain-here    ;; round grain levels to whole numbers
      set max-grain-here grain-here      ;; initial grain level is also maximum
      recolor-patch ]
end

to recolor-patch  ;; patch procedure -- use color to indicate grain level
  set pcolor scale-color yellow grain-here 0 max-grain
end

;; set up the initial values for the turtle variables
to setup-turtles
  set-default-shape turtles "person"
  create-turtles num-people
    [ move-to one-of patches  ;; put turtles on patch centers
      set size 1.5  ;; easier to see
      set-initial-turtle-vars ]
  recolor-turtles
end

to set-initial-turtle-vars
  face one-of neighbors4
  ;; set wealth deterministic
  set wealth starting-wealth
  set ticks-in-poverty 0
end

;; Set the class of the turtles -- if a turtle has less than a third
;; the wealth of the richest turtle, color it red.  If between one
;; and two thirds, color it green.  If over two thirds, color it blue.
to recolor-turtles
  ask turtles
    [ set color choose-by-class red blue ]
end

;;;
;;; GO AND HELPERS
;;;

to go
  compute-class ;; determine social class of turtle

  ask turtles
  [
    harvest
    turn-random
  ]

  ;ask turtles
  ;[
    ;turn-towards-grain
    ;turn-random
  ;]

  ask turtles
  [ move-eat-update ]

  ; poor-die

  recolor-turtles

  ;; grow grain every grain-growth-interval clock ticks
  if ticks mod grain-growth-interval = 0
    [ ask patches [ grow-grain ] ]

  tick
end

;; determine the direction which is most profitable for each turtle in
;; the surrounding patches within the turtles' vision
to turn-towards-grain  ;; turtle procedure
  set heading 0
  let best-direction 0
  let best-amount grain-ahead
  set heading 90
  if (grain-ahead > best-amount)
    [ set best-direction 90
      set best-amount grain-ahead ]
  set heading 180
  if (grain-ahead > best-amount)
    [ set best-direction 180
      set best-amount grain-ahead ]
  set heading 270
  if (grain-ahead > best-amount)
    [ set best-direction 270
      set best-amount grain-ahead ]
  set heading best-direction
end

;; turtles move about at random.
to turn-random  ;; turtle procedure
  ;; up down left right option
  let possible-directions [0 90 180 270]
  let random-direction item random length possible-directions possible-directions
  set heading random-direction
end

to-report grain-ahead  ;; turtle procedure
  let total 0
  let how-far 1
  repeat vision
    [ set total total + [grain-here] of patch-ahead how-far
      set how-far how-far + 1 ]
  report total
end

to grow-grain  ;; patch procedure

  ;; if grain exceeds max, make it max value
  set grain-here min (list grain-here max-grain-here)
  ;; cannot be less than zero
  set grain-here max (list grain-here 0)

  ;; if a patch does not have it's maximum amount of grain, add
  ;; num-grain-grown to its grain amount
  if (grain-here <= max-grain-here)
    [ set grain-here grain-here + num-grain-grown

      ;; if the new amount of grain on a patch is over its maximum
      ;; capacity, set it to its maximum
      if (grain-here > max-grain-here)
        [ set grain-here max-grain-here ]
    ]

  recolor-patch
end

;; each turtle harvests the grain on its patch
;; right now, agent takes as much grain as they can
;; according to the class
to harvest
  harvest-wealth
  recolor-patch
end

; Turtle procedure
to-report harvested-amount-calc
  report choose-by-class lower-class-harvest-amount upper-class-harvest-amount
end

; Turtle procedure
;; Choose by class from lower up to upper
to-report choose-by-class [a b]
  ifelse class = 0.5
  [ report a ]
  [ report b ]
end

; Turtle procedure
to harvest-wealth
  ; Distribute grain evenly amongst all the agents on one patch
  ; Choose either the amount the agent can take or less otherwise
  let harvested-amount (min (list harvested-amount-calc grain-here) / count turtles-here)

  ; decrease grain-here according to the harvested amount
  set grain-here (grain-here - harvested-amount)

  let taxed-amount (choose-by-class lower-tax upper-tax) * harvested-amount / 100

  set state-treasure (state-treasure + taxed-amount)

  let income (harvested-amount - taxed-amount)
  set wealth (wealth + income)
end

; compute class for the turtle
to compute-class
  if (count turtles = 0) [ stop ]

  let max-wealth max [wealth] of turtles
  ask turtles
    [ ifelse (wealth <= max-wealth / 2)
        [ set class 0.5 ]
        [ set class 1 ]
    ]
end

; Put grain according to the charity parameter
to be-kind
  ; The amount that agent can give, excluding expenses for food
  let food-expenses eat-price * max-ticks-in-poverty
  let amount-can-give wealth - food-expenses

  if amount-can-give <= 0 [ stop ]

  let charity-amount (amount-can-give * charity / 100)

  set wealth (wealth - charity-amount)

  ;; set patches around the agent
  ask neighbors
  [
    let grain-amount (max-grain-here - grain-here)
    if charity-amount - grain-amount >= 0
    [
      set grain-here (grain-here + grain-amount)
      set charity-amount (charity-amount - grain-amount)
    ]
  ]

  ;; give back unused charity
  set wealth (wealth + charity-amount)

end

to move-eat-update  ;; turtle procedure
  if (random-float 1 < 0.5) [
    fd 1
  ]


  ifelse (wealth < eat-price) [
      set state-treasure (state-treasure - poverty-fine)
      ; State pays for agents who are in debt
      set ticks-in-poverty (ticks-in-poverty + 1)
  ] [
      set ticks-in-poverty 0
      ; Eat only if the agent has enough money to afford it
      ; set wealth (wealth - eat-price)
  ]

  set wealth (wealth - eat-price)

  be-kind
end

;; Plot according to class
;; if cl = 0 plot all classes
to-report avg-wealth [cl]
  if cl = 0 [ report mean [wealth] of turtles ]

  let cl-turtles [wealth] of turtles with [class = cl]

  ifelse empty? cl-turtles [ report 0 ]
  [ report mean cl-turtles ]
end

to poor-die ;; turtle procedure
  ask turtles [
    if (ticks-in-poverty = max-ticks-in-poverty) [
      set dead-people (dead-people + 1)
      set state-treasure (state-treasure - dead-fine)
    ]
  ]
  ask turtles with [ticks-in-poverty = max-ticks-in-poverty] [
    die
  ]
end

; Statistical procedure
to-report count-below-poverty
    report count turtles with [ticks-in-poverty > 0]
end


; Copyright 1998 Uri Wilensky.
; See Info tab for full copyright and license.
@#$#@#$#@
GRAPHICS-WINDOW
185
10
601
427
-1
-1
8.0
1
10
1
1
1
0
1
1
1
-25
25
-25
25
1
1
1
ticks
30.0

BUTTON
14
360
90
393
setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
101
360
171
393
go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

SLIDER
10
67
178
100
num-people
num-people
2
1000
250.0
1
1
NIL
HORIZONTAL

SLIDER
8
109
176
142
percent-best-land
percent-best-land
5
25
16.0
1
1
%
HORIZONTAL

PLOT
19
454
291
664
Class Plot
Time
Turtles
0.0
50.0
0.0
250.0
true
true
"set-plot-y-range 0 num-people" ""
PENS
"low" 1.0 0 -2674135 true "" "plot count turtles with [color = red]"
"up" 1.0 0 -13345367 true "" "plot count turtles with [color = blue]"
"both" 1.0 0 -16777216 true "" "plot count turtles"

PLOT
338
460
578
660
Class Histogram
Classes
Turtles
0.0
2.0
0.0
250.0
false
false
"set-plot-y-range 0 num-people" ""
PENS
"default" 1.0 1 -2674135 true "" "plot-pen-reset\nset-plot-pen-color red\nplot count turtles with [color = red]\nset-plot-pen-color blue\nplot count turtles with [color = blue]"

SLIDER
6
150
178
183
charity
charity
0
100
2.0
0.1
1
%
HORIZONTAL

PLOT
613
232
863
418
Relative state treasure
Time
Relative wealth
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -14439633 true "" "plot (state-treasure / num-people)"

PLOT
608
457
867
664
Average Wealth
Time
Avg Wealth
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"low" 1.0 0 -2674135 true "" "plot avg-wealth 0.5"
"up" 1.0 0 -13345367 true "" "plot avg-wealth 1"
"both" 1.0 0 -16777216 true "" "plot avg-wealth 0"

SLIDER
6
190
179
223
lower-tax
lower-tax
0
100
6.0
1
1
%
HORIZONTAL

SLIDER
7
230
180
263
upper-tax
upper-tax
0
100
6.0
1
1
%
HORIZONTAL

PLOT
614
27
865
223
Below poverty
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -2674135 true "" "plot count-below-poverty"

@#$#@#$#@
## WHAT IS IT?

This model simulates the distribution of wealth.  "The rich get richer and the poor get poorer" is a familiar saying that expresses inequity in the distribution of wealth.  In this simulation, we see Pareto's law, in which there are a large number of "poor" or red people, fewer "middle class" or green people, and many fewer "rich" or blue people.

## HOW IT WORKS

This model is adapted from Epstein & Axtell's "Sugarscape" model. It uses grain instead of sugar.  Each patch has an amount of grain and a grain capacity (the amount of grain it can grow).  People collect grain from the patches, and eat the grain to survive.  How much grain each person accumulates is his or her wealth.

The model begins with a roughly equal wealth distribution.  The people then wander around the landscape gathering as much grain as they can.  Each person attempts to move in the direction where the most grain lies.  Each time tick, each person eats a certain amount of grain.  This amount is called their metabolism.  People also have a life expectancy.  When their lifespan runs out, or they run out of grain, they die and produce a single offspring.  The offspring has a random metabolism and a random amount of grain, ranging from the poorest person's amount of grain to the richest person's amount of grain.  (There is no inheritance of wealth.)

To observe the equity (or the inequity) of the distribution of wealth, a graphical tool called the Lorenz curve is utilized.  We rank the population by their wealth and then plot the percentage of the population that owns each percentage of the wealth (e.g. 30% of the wealth is owned by 50% of the population).  Hence the ranges on both axes are from 0% to 100%.

Another way to understand the Lorenz curve is to imagine a society of 100 people with a fixed amount of wealth available.  Each individual is 1% of the population.  Rank the individuals in order of their wealth from greatest to least: the poorest individual would have the lowest ranking of 1 and so forth.  Then plot the proportion of the rank of an individual on the y-axis and the portion of wealth owned by this particular individual and all the individuals with lower rankings on the x-axis.  For example, individual Y with a ranking of 20 (20th poorest in society) would have a percentage ranking of 20% in a society of 100 people (or 100 rankings) --- this is the point on the y-axis.  The corresponding plot on the x-axis is the proportion of the wealth that this individual with ranking 20 owns along with the wealth owned by all the individuals with lower rankings (from rankings 1 to 19).  A straight line with a 45 degree incline at the origin (or slope of 1) is a Lorenz curve that represents perfect equality --- everyone holds an equal part of the available wealth.  On the other hand, should only one family or one individual hold all of the wealth in the population (i.e. perfect inequity), then the Lorenz curve will be a backwards "L" where 100% of the wealth is owned by the last percentage proportion of the population.  In practice, the Lorenz curve actually falls somewhere between the straight 45 degree line and the backwards "L".

For a numerical measurement of the inequity in the distribution of wealth, the Gini index (or Gini coefficient) is derived from the Lorenz curve.  To calculate the Gini index, find the area between the 45 degree line of perfect equality and the Lorenz curve.  Divide this quantity by the total area under the 45 degree line of perfect equality (this number is always 0.5 --- the area of 45-45-90 triangle with sides of length 1).  If the Lorenz curve is the 45 degree line then the Gini index would be 0; there is no area between the Lorenz curve and the 45 degree line.  If, however, the Lorenz curve is a backwards "L", then the Gini-Index would be 1 --- the area between the Lorenz curve and the 45 degree line is 0.5; this quantity divided by 0.5 is 1.  Hence, equality in the distribution of wealth is measured on a scale of 0 to 1 --- more inequity as one travels up the scale.  Another way to understand (and equivalently compute) the Gini index, without reference to the Lorenz curve, is to think of it as the mean difference in wealth between all possible pairs of people in the population, expressed as a proportion of the average wealth (see Deltas, 2003 for more).

## HOW TO USE IT

The PERCENT-BEST-LAND slider determines the initial density of patches that are seeded with the maximum amount of grain.  This maximum is adjustable via the MAX-GRAIN variable in the SETUP procedure in the procedures window.  The GRAIN-GROWTH-INTERVAL slider determines how often grain grows.  The NUM-GRAIN-GROWN slider sets how much grain is grown each time GRAIN-GROWTH-INTERVAL allows grain to be grown.

The NUM-PEOPLE slider determines the initial number of people.  LIFE-EXPECTANCY-MIN is the shortest number of ticks that a person can possibly live.  LIFE-EXPECTANCY-MAX is the longest number of ticks that a person can possibly live.  The METABOLISM-MAX slider sets the highest possible amount of grain that a person could eat per clock tick.  The MAX-VISION slider is the furthest possible distance that any person could see.

GO starts the simulation.  The TIME ELAPSED monitor shows the total number of clock ticks since the last setup.  The CLASS PLOT shows a line plot of the number of people in each class over time.  The CLASS HISTOGRAM shows the same information in the form of a histogram.  The LORENZ CURVE plot shows the Lorenz curve of the population at a particular time as well as the 45 degree line of equality.  The GINI-INDEX V. TIME plot shows the Gini index at the time that the Lorenz curve is drawn.  The LORENZ CURVE and the GINI-INDEX V. TIME plots are updated every 5 passes through the GO procedure.

## THINGS TO NOTICE

Notice the distribution of wealth.  Are the classes equal?

This model usually demonstrates Pareto's Law, in which most of the people are poor, fewer are middle class, and very few are rich.  Why does this happen?

Do poor families seem to stay poor?  What about the rich and the middle class people?

Watch the CLASS PLOT to see how long it takes for the classes to reach stable values.

As time passes, does the distribution get more equalized or more skewed?  (Hint: observe the Gini index plot.)

Try to find resources from the U.S. Government Census Bureau for the U.S.'s Gini coefficient.  Are the Gini coefficients that you calculate from the model comparable to those of the Census Bureau?  Why or why not?

Is there a trend in the plotting of the Gini index with respect to time?  Does the plot oscillate?  Or does it stabilize to a certain number?

## THINGS TO TRY

Are there any settings that do not result in a demonstration of Pareto's Law?

Play with the NUM-GRAIN-GROWN slider, and see how this affects the distribution of wealth.

How much does the LIFE-EXPECTANCY-MAX matter?

Change the value of the MAX-GRAIN variable (in the `setup` procedure in the Code tab).  Do outcomes differ?

Experiment with the PERCENT-BEST-LAND and NUM-PEOPLE sliders.  How do these affect the outcome of the distribution of wealth?

Try having all the people start in one location. See what happens.

Try setting everyone's initial wealth as being equal.  Does the initial endowment of an individual still arrive at an unequal distribution in wealth?  Is it less so when setting random initial wealth for each individual?

Try setting all the individual's wealth and vision to being equal.  Do you still arrive at an unequal distribution of wealth?  Is it more equal in the measure of the Gini index than with random endowments of vision?

## EXTENDING THE MODEL

Have each newborn inherit a percentage of the wealth of its parent.

Add a switch or slider which has the patches grow back all or a percentage of their grain capacity, rather than just one unit of grain.

Allow the grain to give an advantage or disadvantage to its carrier, such as every time some grain is eaten or harvested, pollution is created.

Would this model be the same if the wealth were randomly distributed (as opposed to a gradient)?  Try different landscapes, making SETUP buttons for each new landscape.

Try allowing metabolism or vision or another characteristic to be inherited.  Will we see any sort of evolution?  Will the "fittest" survive? If not, why not?

We said above that "there is no inheritance of wealth" in the model, but that is not entirely true. New turtles are born in the same location as their parents. If grain is plentiful relative to the population at this location, they inherit a good starting situation. Try moving the turtles to a random patch when they are born. Does that lead to a more equitable distribution of wealth?

Try adding in seasons into the model.  That is to say have the grain grow better in a section of the landscape during certain times and worse at others.

How could you change the model to achieve wealth equality?

The way the procedures are set up now, one person will sometimes follow another.  You can see this by setting the number of people relatively low, such as 50 or 100, and having a long life expectancy.  Why does this phenomenon happen?  Try adding code to prevent this from occurring.  (Hint: When and how do people check to see which direction they should move in?)

## NETLOGO FEATURES

Examine how the landscape of color is created --- note the use of the `scale-color` reporter.  Each patch is given a value, and `scale-color` reports a color for each patch that is scaled according to its value.

Note the use of lists in drawing the Lorenz Curve and computing the Gini index.

## CREDITS AND REFERENCES

This model is based on a model described in Epstein, J. & Axtell R. (1996). Growing Artificial Societies: Social Science from the Bottom Up. Washington, DC: Brookings Institution Press.

For an explanation of Pareto's Law, see https://en.wikipedia.org/wiki/Pareto_principle.

For more on the calculation of the Gini index see:

 * Deltas, George (2003).  The Small-Sample Bias of the Gini Coefficient:  Results and Implications for Empirical Research.  The Review of Economics and Statistics, February 2003, 85(1): 226-234.

In particular, note that if one is calculating the Gini index of a sample for the purpose of estimating the value for a larger population, a small correction factor to the method used here may be needed for small samples.

## HOW TO CITE

If you mention this model or the NetLogo software in a publication, we ask that you include the citations below.

For the model itself:

* Wilensky, U. (1998).  NetLogo Wealth Distribution model.  http://ccl.northwestern.edu/netlogo/models/WealthDistribution.  Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

Please cite the NetLogo software as:

* Wilensky, U. (1999). NetLogo. http://ccl.northwestern.edu/netlogo/. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

## COPYRIGHT AND LICENSE

Copyright 1998 Uri Wilensky.

![CC BY-NC-SA 3.0](http://ccl.northwestern.edu/images/creativecommons/byncsa.png)

This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 3.0 License.  To view a copy of this license, visit https://creativecommons.org/licenses/by-nc-sa/3.0/ or send a letter to Creative Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.

Commercial licenses are also available. To inquire about commercial licenses, please contact Uri Wilensky at uri@northwestern.edu.

This model was created as part of the project: CONNECTED MATHEMATICS: MAKING SENSE OF COMPLEX PHENOMENA THROUGH BUILDING OBJECT-BASED PARALLEL MODELS (OBPML).  The project gratefully acknowledges the support of the National Science Foundation (Applications of Advanced Technologies Program) -- grant numbers RED #9552950 and REC #9632612.

This model was converted to NetLogo as part of the projects: PARTICIPATORY SIMULATIONS: NETWORK-BASED DESIGN FOR SYSTEMS LEARNING IN CLASSROOMS and/or INTEGRATED SIMULATION AND MODELING ENVIRONMENT. The project gratefully acknowledges the support of the National Science Foundation (REPP & ROLE programs) -- grant numbers REC #9814682 and REC-0126227. Converted from StarLogoT to NetLogo, 2001.

<!-- 1998 2001 -->
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.3.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="Experiment_charity" repetitions="5" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="5000"/>
    <metric>count-below-poverty</metric>
    <enumeratedValueSet variable="lower-tax">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="percent-best-land">
      <value value="16"/>
    </enumeratedValueSet>
    <steppedValueSet variable="charity" first="0" step="1" last="100"/>
    <enumeratedValueSet variable="upper-tax">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-people">
      <value value="250"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Experiment_charity_0_to_8" repetitions="5" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="5000"/>
    <metric>count-below-poverty</metric>
    <enumeratedValueSet variable="lower-tax">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="upper-tax">
      <value value="0"/>
    </enumeratedValueSet>
    <steppedValueSet variable="charity" first="0" step="0.1" last="8"/>
    <enumeratedValueSet variable="num-people">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="percent-best-land">
      <value value="16"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 30 225
Line -7500403 true 150 150 270 225
@#$#@#$#@
0
@#$#@#$#@
