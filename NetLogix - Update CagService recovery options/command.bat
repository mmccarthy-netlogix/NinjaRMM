sc config cagservice start= delayed-auto
sc failure cagservice reset= 86400 actions= restart/60000/restart/60000/restart/300000