#!/bin/bash
# Runs every E13 measurement on one simulator, 3 passes, arms in turn.
set -u
U="$1"; O="${2:-build/m}"
A=build/out
for m in jump older textb textm; do ./measure.sh $m "$U" "$O" 3 $A/SolShipped.app $A/SolJump20.app $A/SolOneCell.app $A/SolFix.app; done
./measure.sh stream "$U" "$O" 3 $A/SolShipped.app $A/SolPerMsg.app $A/SolNextTurn.app $A/SolFrame.app $A/SolTrimBatch.app $A/SolPrefetchOn.app $A/SolOneCell.app $A/SolFix.app
./measure.sh stream1 "$U" "$O" 3 $A/SolShipped.app $A/SolPerMsg.app $A/SolNextTurn.app $A/SolFrame.app
./measure.sh fling "$U" "$O" 3 $A/SolShipped.app $A/SolPrefetchOn.app $A/SolOneCell.app $A/SolFix.app
./measure.sh callback "$U" "$O" 1 $A/SolShipped.app
echo ALLDONE
