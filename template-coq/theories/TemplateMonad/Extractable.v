From Coq Require Import Strings.String.
From Template Require Import
     Ast AstUtils TemplateMonad.Common.

Set Universe Polymorphism.
Set Universe Minimization ToSet.
Set Primitive Projections.
Set Printing Universes.

(** ** The Extractable Template Monad

  A monad for programming with Template Coq structures. Use [Run
  TemplateProgram] on a monad action to produce its side-effects.

 *)


Cumulative Inductive TM@{t} : Type@{t} -> Type :=
(* Monadic operations *)
| tmReturn {A:Type@{t}}
  : A -> TM A
| tmBind {A B : Type@{t}}
  : TM A -> (A -> TM B) -> TM B

(* General commands *)
| tmPrint : Ast.term -> TM unit
| tmMsg  : string -> TM unit
| tmFail : forall {A:Type@{t}}, string -> TM A
| tmEval (red : reductionStrategy) (tm : Ast.term)
  : TM Ast.term

(* Return the defined constant *)
| tmDefinition (nm : ident)
               (type : option Ast.term) (term : Ast.term)
  : TM kername
| tmAxiom (nm : ident)
          (type : Ast.term)
  : TM kername
| tmLemma (nm : ident)
          (type : Ast.term)
  : TM kername

(* Guaranteed to not cause "... already declared" error *)
| tmFreshName : ident -> TM ident

| tmAbout : ident -> TM (option global_reference)
| tmCurrentModPath : unit -> TM string

(* Quote the body of a definition or inductive. *)
| tmQuoteInductive (nm : kername)
  : TM mutual_inductive_body
| tmQuoteUniverses : TM uGraph.t
| tmQuoteConstant (nm : kername) (bypass_opacity : bool)
  : TM constant_entry

(* unquote before making the definition *)
(* FIXME take an optional universe context as well *)
| tmMkInductive : mutual_inductive_entry -> TM unit

(* Typeclass registration and querying for an instance *)
| tmExistingInstance : kername -> TM unit
| tmInferInstance (type : Ast.term)
  : TM (option Ast.term)
.

Definition TypeInstance : Common.TMInstance :=
  {| Common.TemplateMonad := TM
   ; Common.tmReturn:=@tmReturn
   ; Common.tmBind:=@tmBind
   ; Common.tmFail:=@tmFail
   ; Common.tmFreshName:=@tmFreshName
   ; Common.tmAbout:=@tmAbout
   ; Common.tmCurrentModPath:=@tmCurrentModPath
   ; Common.tmQuoteInductive:=@tmQuoteInductive
   ; Common.tmQuoteUniverses:=@tmQuoteUniverses
   ; Common.tmQuoteConstant:=@tmQuoteConstant
   ; Common.tmMkInductive:=@tmMkInductive
   ; Common.tmExistingInstance:=@tmExistingInstance
   |}.
(* Monadic operations *)

Definition tmMkInductive' (mind : mutual_inductive_body) : TM unit
  := tmMkInductive (mind_body_to_entry mind).

Definition tmLemmaRed (i : ident) (rd : reductionStrategy)
           (ty : Ast.term) :=
  tmBind (tmEval rd ty) (fun ty => tmLemma i ty).
Definition tmAxiomRed (i : ident) (rd : reductionStrategy) (ty : Ast.term)
  :=
    tmBind (tmEval rd ty) (fun ty => tmAxiom i ty).
Definition tmDefinitionRed (i : ident) (rd : reductionStrategy)
           (ty : option Ast.term) (body : Ast.term) :=
  match ty with
  | None => tmDefinition i None body
  | Some ty =>
    tmBind (tmEval rd ty) (fun ty => tmDefinition i (Some ty) body)
  end.

Definition tmInferInstanceRed (rd : reductionStrategy) (type : Ast.term)
  : TM (option Ast.term) :=
  tmBind (tmEval rd type) (fun type => tmInferInstance type).