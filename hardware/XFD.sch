v 20110115 2
C 40000 40000 0 0 0 title-B.sym
C 40400 46900 1 0 0 connector6-1.sym
{
T 42200 48700 5 10 0 0 0 0 1
device=CONNECTOR_6
T 40500 48900 5 10 1 1 0 0 1
refdes=CONN1
T 40400 46700 5 10 1 1 0 0 1
description=Connection to PICKit 2 programmer
}
C 56300 47100 1 0 1 connector4-1.sym
{
T 54500 48000 5 10 0 0 0 6 1
device=CONNECTOR_4
T 56300 48500 5 10 1 1 0 6 1
refdes=CONN3
T 55800 46900 5 10 1 1 0 0 1
description=USB B-socket
}
C 56300 44600 1 0 1 connector4-1.sym
{
T 54500 45500 5 10 0 0 0 6 1
device=CONNECTOR_4
T 56300 46000 5 10 1 1 0 6 1
refdes=CONN2
T 56300 44400 5 10 1 1 0 6 1
description=To the traffic light
}
N 54200 48200 54600 48200 4
N 51300 48300 53300 48300 4
N 53300 47100 53300 50500 4
N 53300 47300 54600 47300 4
N 51300 47500 53500 47500 4
N 53500 47500 53900 47900 4
N 53900 47900 54600 47900 4
N 53900 47600 54600 47600 4
N 53900 47600 53600 47900 4
N 53600 47900 51300 47900 4
C 42100 47000 1 0 0 nc-right-1.sym
{
T 42200 47500 5 10 0 0 0 0 1
value=NoConnection
T 42200 47700 5 10 0 0 0 0 1
device=DRC_Directive
}
N 42100 48300 45000 48300 4
N 43400 50800 54200 50800 4
N 54200 45700 54200 50800 4
N 42200 50500 53300 50500 4
N 42100 47700 42500 47700 4
N 42500 47700 42500 50200 4
N 42500 50200 52700 50200 4
N 52700 50200 52700 47900 4
N 42100 47400 43100 47400 4
N 43100 47400 43100 49900 4
N 43100 49900 52400 49900 4
C 44900 47200 1 90 0 resistor-2.sym
{
T 44550 47600 5 10 0 0 90 0 1
device=RESISTOR
T 44700 47200 5 10 1 1 90 0 1
refdes=R1
T 44900 47500 5 10 1 1 90 0 1
value=10k
}
C 51300 45400 1 0 0 resistor-2.sym
{
T 51700 45750 5 10 0 0 0 0 1
device=RESISTOR
T 51500 45600 5 10 1 1 0 0 1
refdes=R2
T 51600 45400 5 10 1 1 0 0 1
value=150
}
C 51300 45000 1 0 0 resistor-2.sym
{
T 51700 45350 5 10 0 0 0 0 1
device=RESISTOR
T 51500 45200 5 10 1 1 0 0 1
refdes=R3
T 51600 45000 5 10 1 1 0 0 1
value=150
}
C 51300 44600 1 0 0 resistor-2.sym
{
T 51700 44950 5 10 0 0 0 0 1
device=RESISTOR
T 51500 44800 5 10 1 1 0 0 1
refdes=R4
T 51600 44600 5 10 1 1 0 0 1
value=150
}
C 51300 46900 1 0 0 capacitor-1.sym
{
T 51500 47600 5 10 0 0 0 0 1
device=CAPACITOR
T 51500 47300 5 10 1 1 0 0 1
refdes=C1
T 51500 47800 5 10 0 0 0 0 1
symversion=0.1
T 51800 46900 5 10 1 1 0 0 1
value=100n
}
C 47800 49100 1 0 0 capacitor-1.sym
{
T 48000 49800 5 10 0 0 0 0 1
device=CAPACITOR
T 48000 49500 5 10 1 1 0 0 1
refdes=C2
T 48000 50000 5 10 0 0 0 0 1
symversion=0.1
T 48300 49100 5 10 1 1 0 0 1
value=100n
}
C 45000 44300 1 0 0 pic18F13K50-1.sym
{
T 50900 49000 5 10 1 1 0 0 1
refdes=U1
T 52200 46500 5 10 0 0 0 0 1
device=PIC18F13K50
T 52200 46200 5 10 0 0 0 0 1
footprint=DIP20
}
N 42800 47100 45000 47100 4
N 42100 48600 42800 48600 4
N 42800 48600 42800 47100 4
N 44800 47200 44800 47100 4
N 44800 48100 44800 48300 4
N 42200 50500 42200 48000 4
N 43400 50800 43400 48300 4
N 52400 49900 52400 47500 4
N 52200 45100 54600 45100 4
N 52200 45500 54600 45500 4
N 54600 45500 54600 45400 4
N 52200 44700 54600 44700 4
N 54600 44700 54600 44800 4
N 54200 45700 54600 45700 4
N 43400 49300 47800 49300 4
N 48700 49300 51900 49300 4
N 51900 49300 51900 48300 4
N 52200 47100 53300 47100 4
C 44500 47400 1 90 0 crystal-1.sym
{
T 44000 47600 5 10 0 0 90 0 1
device=CRYSTAL
T 44300 47800 5 10 1 1 180 0 1
refdes=U2
T 43800 47600 5 10 0 0 90 0 1
symversion=0.1
}
C 43300 47800 1 0 0 capacitor-1.sym
{
T 43500 48500 5 10 0 0 0 0 1
device=CAPACITOR
T 43500 48100 5 10 1 1 0 0 1
refdes=C3
T 43500 48700 5 10 0 0 0 0 1
symversion=0.1
T 43800 48100 5 10 1 1 0 0 1
value=15p
}
C 43300 47300 1 0 0 capacitor-1.sym
{
T 43500 48000 5 10 0 0 0 0 1
device=CAPACITOR
T 43500 47600 5 10 1 1 0 0 1
refdes=C4
T 43500 48200 5 10 0 0 0 0 1
symversion=0.1
T 43800 47300 5 10 1 1 0 0 1
value=15p
}
N 42100 48000 43300 48000 4
N 43300 48000 43300 47500 4
N 44500 47500 45000 47500 4
N 44500 47500 44400 47400 4
N 44300 48000 44400 48100 4
N 44600 47900 44400 48100 4
N 45000 47900 44600 47900 4
N 44300 47500 44400 47400 4
N 44200 48000 44300 48000 4
N 44200 47500 44300 47500 4
