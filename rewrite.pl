/*  Part of SWI-Prolog

    Author:        Jan Wielemaker
    E-mail:        J.Wielemaker@uva.nl
    WWW:           http://www.swi-prolog.org
    Copyright (C): 2010, University of Amsterdam

    This program is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License
    as published by the Free Software Foundation; either version 2
    of the License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public
    License along with this library; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

    As a special exception, if you link this library with other files,
    compiled with a Free Software compiler, to produce an executable, this
    library does not by itself cause the resulting executable to be covered
    by the GNU General Public License. This exception does not however
    invalidate any other reasons why the executable file might be covered by
    the GNU General Public License.
*/

:- module(rewrite,
	  [ rewrite/2,			% +Rule, +Input
	    rew_term_expansion/2,
	    rew_goal_expansion/2,

	    op(1200, xfx, (::=))
	  ]).
:- use_module(library(quintus)).

:- meta_predicate
	rewrite(1, +).

		 /*******************************
		 *	    COMPILATION		*
		 *******************************/

rew_term_expansion((Rule ::= RuleBody), (Head :- Body)) :-
	translate(RuleBody, Term, Body0),
	simplify(Body0, Body),
	Rule =.. [Name|List],
	Head =.. [Name,Term|List].

rew_goal_expansion(rewrite(To, From), Goal) :-
	nonvar(To),
	To = \Rule,
	callable(Rule),
	Rule =.. [Name|List],
	Goal =.. [Name,From|List].


		 /*******************************
		 *	      TOPLEVEL		*
		 *******************************/

%%	rewrite(:To, +From)
%
%	Invoke the term-rewriting system

rewrite(M:T, From) :-
	(   var(T)
	->  From = T
	;   T = \Rule
	->  Rule =.. [Name|List],
	    Goal =.. [Name,From|List],
	    M:Goal
	;   match(T, M, From)
	).

match(Rule, M, From) :-
	translate(Rule, From, Code),
	M:Code.

translate(Var, Var, true) :-
	var(Var), !.
translate((\Command, !), Var, (Goal, !)) :- !,
	(   callable(Command),
	    Command =.. [Name|List]
	->  Goal =.. [Name,Var|List]
	;   Goal = rewrite(\Command, Var)
	).
translate(\Command, Var, Goal) :- !,
	(   callable(Command),
	    Command =.. [Name|List]
	->  Goal =.. [Name,Var|List]
	;   Goal = rewrite(\Command, Var)
	).
translate(Atomic, Atomic, true) :-
	atomic(Atomic), !.
translate(C, _, Cmd) :-
	command(C, Cmd), !.
translate((A, B), T, Code) :-
	(   command(A, Cmd)
	->  !, translate(B, T, C),
	    Code = (Cmd, C)
	;   command(B, Cmd)
	->  !, translate(A, T, C),
	    Code = (C, Cmd)
	).
translate(Term0, Term, Command) :-
	functor(Term0, Name, Arity),
	functor(Term, Name, Arity),
	translate_args(0, Arity, Term0, Term, Command).

translate_args(N, N, _, _, true) :- !.
translate_args(I0, Arity, T0, T1, (C0,C)) :-
	I is I0 + 1,
	arg(I, T0, A0),
	arg(I, T1, A1),
	translate(A0, A1, C0),
	translate_args(I, Arity, T0, T1, C).

command(0, _) :- !,			% catch variables
	fail.
command({A}, A).
command(!, !).

		 /*******************************
		 *	      SIMPLIFY		*
		 *******************************/

%%	simplify(+Raw, -Simplified)
%
%	Get rid of redundant `true' goals generated by translate/3.

simplify(V, V) :-
	var(V), !.
simplify((A0,B), A) :-
	B == true, !,
	simplify(A0, A).
simplify((A,B0), B) :-
	A == true, !,
	simplify(B0, B).
simplify((A0, B0), C) :- !,
	simplify(A0, A),
	simplify(B0, B),
	(   (   A \== A0
	    ;	B \== B0
	    )
	->  simplify((A,B), C)
	;   C = (A,B)
	).
simplify(X, X).

		 /*******************************
		 *	       XREF		*
		 *******************************/

:- multifile
	prolog:called_by/2.

prolog:called_by(rewrite(Spec, _Term), Called) :-
	findall(G+1, sub_term(\G, Spec), Called).
