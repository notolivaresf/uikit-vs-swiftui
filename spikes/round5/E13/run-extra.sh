#!/bin/bash
# Second E13 batch: a one-line header measure and a combined fix with next-turn grouping.
set -u
U="$1"; O="${2:-build/m2}"
A=build/out
for m in jump textb textm older; do ./measure.sh $m "$U" "$O" 3 $A/SolShipped.app $A/SolHeader.app $A/SolFix2.app; done
./measure.sh stream "$U" "$O" 3 $A/SolShipped.app $A/SolNextTurn.app $A/SolFix2.app
./measure.sh stream1 "$U" "$O" 3 $A/SolFix2.app
echo ALLDONE
