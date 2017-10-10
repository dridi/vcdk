dnl Copyright (C) 2017  Dridi Boukelmoune
dnl All rights reserved.
dnl
dnl This program is free software: you can redistribute it and/or modify
dnl it under the terms of the GNU General Public License as published by
dnl the Free Software Foundation, either version 3 of the License, or
dnl (at your option) any later version.
dnl
dnl This program is distributed in the hope that it will be useful,
dnl but WITHOUT ANY WARRANTY; without even the implied warranty of
dnl MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
dnl GNU General Public License for more details.
dnl
dnl You should have received a copy of the GNU General Public License
dnl along with this program.  If not, see <http://www.gnu.org/licenses/>.
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
