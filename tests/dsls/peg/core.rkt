#lang racket/base

(provide
 ; core forms
 eps
 seq
 alt
 plain-alt
 ?
 *
 !
 =>
 token
 text
 char
 (rename-out [bind :]
             [src-span :src-span])

 ; interface macros
 define-peg
 define-pegs
 parse

 ; default #%peg-datum implementation
 #%peg-datum

 make-text
 ; result datatype
 (struct-out parse-result)

 ; interfaces for macro definitions and local-expansion
 (for-syntax
  local-expand-peg
  peg-macro))

(require
  "private/forms.rkt"
  "private/runtime.rkt"
  "private/compile.rkt"
  (for-syntax
   "private/leftrec-check.rkt"))

(require
  syntax-spec
  (for-syntax
   syntax-spec/private/syntax/syntax-classes
   racket/base
   syntax/parse
   (rename-in syntax/parse [define/syntax-parse def/stx])))

(begin-for-syntax
  (define-syntax-class string-stx
    (pattern _:string)))

(syntax-spec
  (binding-class var #:description "PEG variable")
  (binding-class nonterm #:description "PEG nonterminal")
  (extension-class peg-macro #:description "PEG macro")

  (nonterminal text-expr
    s:string-stx
    e:racket-expr)

  (nonterminal/nesting peg (tail)
    #:description "PEG expression"
    #:allow-extension peg-macro
    
    (~> p:ref-id #'(bind p.var p.ref))

    (bind v:var ps:peg)
    #:binding (nest-one ps {(bind v) tail})

    (seq ps1:peg ps2:peg)
    #:binding (nest-one ps1 (nest-one ps2 tail))

    (alt e1:peg e2:peg)

    (? e:peg)
    #:binding (nest-one e tail)

    (plain-alt e1:peg e2:peg)
    ;; TODO: why is plain alt different than alt?
    #:binding (nest-one e1 (nest-one e2 tail))

    (* ps:peg)
    #:binding (nest-one ps tail)

    (src-span v:var ps:peg)
    #:binding {(bind v) (nest-one ps tail)}

    eps
    (char e:expr)
    (token e:expr)
    (! e:peg)

    (~> (~or s:string s:char s:number s:regexp)
        #:with #%peg-datum (datum->syntax #'s '#%peg-datum)
        #'(#%peg-datum s))

    (text e:text-expr)

    (=> ps:peg e:racket-expr)
    #:binding (nest-one ps e)

    (~> n:id #'(#%nonterm-ref n))
    (#%nonterm-ref n:nonterm))

  (host-interface/definitions
   (define-pegs [name:nonterm p:peg] ...)
   #:binding (export name)
   (run-leftrec-check! (attribute name) (attribute p))
   #'(begin (define name (lambda (in) (with-reference-compilers ([var immutable-reference-compiler])
                                        (compile-peg p in))))
            ...))

  (host-interface/expression
   (parse name:nonterm in-e:expr)
   #'(compile-parse name in-e)))

; Interface macros

(define-syntax-rule (define-peg name peg) (define-pegs [name peg]))

; Default implementation of #%peg-datum interposition point

(define-syntax #%peg-datum
  (peg-macro
   (syntax-parser
     [(_ (~or* v:char v:string)) #'(text v)])))

(begin-for-syntax
  (define local-expand-peg (nonterminal-expander peg)))
