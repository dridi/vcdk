changequote(`[', `]')dnl
divert([-1])

define([_arg1], [$1])

define([foreachc], [dnl
pushdef([$1])dnl
pushdef([$3])dnl
_foreachc($@)dnl
popdef([$3])dnl
popdef([$1])dnl
])

define([_foreachc], [ifelse([$4], [()], [], [dnl
define([$1], ifelse((shift$4), [()], [], [$2]))dnl
define([$3], _arg1$4)dnl
$5[]$0([$1], [$2], [$3], (shift$4), [$5])dnl
])])

define([to_upper], [translit([$1], [a-z], [A-Z])])

divert[]dnl
