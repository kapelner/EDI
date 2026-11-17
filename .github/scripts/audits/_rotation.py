"""Rotation helpers shared by the monthly code-review audits. Not an audit (leading underscore).

The rotation itself is the framework's: these audits set SPEC "period": "month", so a cycle of
N is N of the job's own monthly runs (audit_common.in_rotation). Two cases need a unit to stay
out of the rotation slice, which a unit does by setting its own `cycle_weeks` to NEVER (a cycle
so long that the slice test never matches in practice: the unit's slot would have to equal the
month index, about 1 chance in 10**9):

- a push run (rpy-parity also runs after a push): only new, changed and open-finding units are
  read, so repeated pushes in one month do not re-read the month's slice;
- compiled-code units, which are re-read only when their assembly changes (plan Part 5).
"""
NEVER = 10 ** 9


def unit_cycle(spec_cycle, event):
    """The `cycle_weeks` a unit should carry: the SPEC's cycle, or NEVER on a push run."""
    return NEVER if event == "push" else spec_cycle
