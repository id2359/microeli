;-----------------------------------------------------------------------
;
;                    MICRO ELI (English Language Interpreter)
;
; Micro conceptual analyser translated into Chez Scheme 3.9 from the
; Lisp version in Inside Computer Understanding [Schank and Riesbeck 
; 1981]  To test it, use (process-text kite-text), which parses the
; sentences 
;
;   (JACK WENT TO THE STORE)
;   (HE GOT A KITE)
;   (HE WENT HOME)
;

; PROCESS-TEXT takes a list of sentences and parses each one, printing 
; the resulting conceptualization.
(use-modules (ice-9 pretty-print))


(define kite-text '(
                    (jack went to the store)
                    (he got a kite)
                    (he went home)))

(define *concept* '())

(define *word-defs* '())
(define *stack* '())
(define *word* '())
(define *sentence* '())
(define *part-of-speech* '())
(define *cd-form* '())
(define *subject* '())
(define *predicates* '())
(define go-var1 '())
(define go-var2 '())
(define go-var3 '())
(define get-var1 '())
(define get-var2 '())
(define get-var3 '())



(define process-text
   (lambda (text)
      (cond
         ((null? text)
          '())
         (else
          (format #t  "~%Input is: ~a~%" (car text))
          (let ((cd (parse (car text))))
             (format #t  "~%~%The CD form is:~% ")
             (pretty-print cd)
             (process-text (cdr text)))))))

; Parse takes a sentence in list form--- e.g., (JACK WENT TO THE STORE)---
; and returns the conceptual analysis for it.  It sets *SENTENCE* to the
; input sentence with the atom *START* stuck in front.  *START* is a
; pseudo-word in the dictionary that is associated with information useful
; for starting the analysis.
;
; PARSE take *SENTENCE* one word at a time, setting *WORD* to the current
; word, and loading the packet for that word (if any) onto *STACK*.  Then
; it calls RUN-STACK which looks for and executes triggered requests.
;
; During the analysis, the variable *CONCEPT* will be set to the main
; concept of the sentence (usually by the packet under the main verb).
; Since McELI builds CD forms with variables in them, McELI has to remove
; these variables when the sentence is finished, using the function
; REMOVE-VARIABLES.
;
; PARSE returns the CD with all the variables filled in, while *CONCEPT*
; still holds the original CD, including unfilled variables.

(define parse
   (lambda (sentence)
      (set! *concept* '())
      (set! *stack* '())
      (set! *word* '())
      (set! *sentence* (cons '*start* sentence))
      (parse*)))

(define parse* 
   (lambda ()
      (cond
         ((null? *sentence*)
          (remove-variables *concept*))
         (else
          (set! *word* (car *sentence*))
          (set! *sentence* (cdr *sentence*))
          (format #t  "~% Processing ~a~%" *word*)
          (load-def)
          (run-stack)
          (parse*)))))

; RUN-STACK
; As long as some request in the packet on top of the stack can be
; triggered, the whole packet is removed from the stack, and that
; request is executed and saved.  
; When the top packet does not contain any triggerable requests,
; the packets in the requests that were executed and saved (if any)
; are added to the stack.

(define run-stack
   (lambda ()
      (run-stack* '())))

(define run-stack*
   (lambda (triggered)
      (let ((request (check-top *stack*)))
        (cond
           ((null? request)
            (add-packets triggered))
           (else
            (set! *stack* (cdr *stack*))
            (do-assigns request)
            (run-stack* (cons request triggered)))))))


; CHECK-TOP gets the first request in the packet on top of the stack
; with a true test (if any).
 
(define check-top
   (lambda (stack)
      (cond
        ((null? stack)
         '())
        (else
          (check-packet (top-of stack))))))

(define check-packet
   (lambda (packet)
      (cond
         ((null? packet)
          '())
         ((is-triggered? (car packet))
          (car packet))
         (else
          (check-packet (cdr packet))))))

; IS-TRIGGERED? returns true if a request has no test at all, or if it
; has a test and the test evaluates to true.

(define is-triggered?
   (lambda (request)
      (let ((test (req-clause 'test request)))
        (or (null? test) (primitive-eval (car test))))))

; DO-ASSIGNS sets the variables given in the ASSIGN clause.

(define do-assigns 
   (lambda (request)
      (do-assigns* (req-clause 'assign request))))

(define do-assigns*
   (lambda (assignments)
      (cond
        ((null? assignments)
         '())
        (else
          (reassign (car assignments) (cadr assignments))
          (do-assigns* (cddr assignments))))))

; REASSIGN sets VAR to the value of VAL and prints a message saying it
; did it.  Note that if VAL is '(), nothing is printed.

(define reassign
   (lambda (var val)
      (let ((new-val (primitive-eval val)))
        (if (not (null? new-val))
            (begin (format #t  "~%  ~a =~%  " var)
                   (pretty-print new-val)))
        (primitive-eval `(set! ,var ',new-val)))))


; ADD-PACKETS takes a list of requests and adds their NEXT-PACKETS
; to the stack.

(define add-packets
   (lambda (requests)
      (cond
         ((null? requests)
          '())
         (else
          (add-stack (req-clause 'next-packet (car requests)))
          (add-packets (cdr requests))))))


; REMOVE-VARIABLES takes a parsed CD from ELI and returns a copy of
; the pattern with the variables replaced by values.  '() fillers, and
; their roles, are left out of the final CD.
;
; Note that McELI's REMOVE-VARIABLES is like INSTANTIATE in McSAM,
; except that Lisp values rather than binding lists are used to hold
; the values of variables.


(define (atom? x)
  (not (or (pair? x)
           (vector? x))))

(define remove-variables
   (lambda (cd-form)
      (cond
         ((atom? cd-form)
          cd-form)
         ((is-var? cd-form)
          (remove-variables (primitive-eval (name:var cd-form))))
         (else
          (cons (header:cd cd-form)
                (remove-slot-variables (roles:cd cd-form)))))))

(define remove-slot-variables
   (lambda (role-pairs)
      (cond
         ((null? role-pairs)
          '())
         (else
           (let ((val (remove-variables (filler:pair (car role-pairs)))))
              (if (not (null? val))
                  (cons (list (role:pair (car role-pairs))
                              val)
                        (remove-slot-variables (cdr role-pairs)))
                  (remove-slot-variables (cdr role-pairs))))))))


;                           DATA STRUCTURES
;
; McELI uses a stack for control.  The top of the stack is the first
; element of the list.

(define top-of
   (lambda (stack)
      (car stack)))

; ADD-STACK puts a packet at the front of the list of pending packets.

(define add-stack
   (lambda (packet)
      (if (not (null? packet))
          (set! *stack* (cons packet *stack*)))
      packet))

; Word definitions are stored under the words, in an association list.
; LOAD-DEF adds a word's request packet to the stack.

(define load-def
   (lambda ()
      (let ((packet-assn (assoc *word* *word-defs*)))
         (cond
            ((not packet-assn)
             (format #t  "~%  --- `~a' is not in the dictionary.~%" *word*)
             '())
            (else
             (add-stack (cadr packet-assn)))))))

; REQ-CLAUSE gets clauses from a list of the form
; ((test...) (assing...) (next-packet...))

(define req-clause
   (lambda (key l)
      (let ((x (assoc key l)))
         (if (not x)
             '()
             (cdr x)))))


; Some sample sentences for McELI to parse

(set! kite-text
      '((jack went to the store)
        (he got a kite)
        (he went home)))


;                         The dictionary             
;
; (DEF-WORD word 'request1 request2 . . .)) stores a definition under a
; word consisting of the list (request1 request2 . . .)

(set! *word-defs* '())

(define def-word
  (lambda (w . l)
    (set! *word-defs* (cons (list w l) *word-defs*))))

; He is a noun phrase that means a person.

(def-word 'he 
  '((assign *part-of-speech* 'noun-phrase *cd-form* '(person))))

; JACK is a noun phrase that means a person named Jack.

(def-word 'jack 
  '((assign *cd-form* '(person (name (jack))) *part-of-speech* 'noun-phrase)))

          
; GOT is a verb that means someone ATRANSed something to the subject.  
; GOT looks for a noun phrase to fill the object slot.

(def-word 'got
  '((assign *part-of-speech* 'verb
     *cd-form* '(atrans (actor (*var* get-var3))
                        (object (*var* get-var2))
                        (to (*var* get-var1))
                        (from (*var* get-var3)))
     get-var1 *subject*
     get-var2 '()
     get-var3 '())
    (next-packet
      ((test (equal? *part-of-speech* 'noun-phrase))
       (assign get-var2 *cd-form*)))))
      
; WENT is a verb that means someone (the subject) PTRANSed himself
; from somewhere to somewhere.  WENT looks for "to <noun phrase>" or
; "home" to fill the TO slot.

(def-word 'went
  '((assign *part-of-speech* 'verb
            *cd-form* '(ptrans (actor (*var* go-var1))
                               (object (*var* go-var1))
                               (to (*var* go-var2)) 
                               (from (*var* go-var3)))
            go-var1 *subject*
            go-var2 '()
            go-var3 '())
    (next-packet
       ((test (equal? *word* 'to))
        (next-packet
          ((test (equal? *part-of-speech* 'noun-phrase))
           (assign go-var2 *cd-form*))))
       ((test (equal? *word* 'home))
        (assign go-var2 '(house))))))


; A looks for a noun to build a noun phrase with.

(def-word 'a
  '((test (equal? *part-of-speech* 'noun))
    (assign *part-of-speech* 'noun-phrase
            *cd-form* (append *cd-form* *predicates*)
            *predicates* '())))

; THE is identical to A as far as McELI is concerned.

(def-word 'the
  '((test (equal? *part-of-speech* 'noun))
    (assign *part-of-speech* 'noun-phrase
            *cd-form* (append *cd-form* *predicates*)
            *predicates* '())))

; KITE is a noun that builds the concept KITE.

(def-word 'kite
   '((assign *part-of-speech* 'noun
             *cd-form* '(kite))))

; STORE is a noun that builds the concept STORE.

(def-word 'store
   '((assign *part-of-speech* 'noun
             *cd-form* '(store))))


; *START* is loaded at the start of each sentence.  It looks for a noun
; phrase (the subject) followed by a verb (the main concept).

; The following variables are English-oriented.  They are used only
; by the dictionary entries, not by the central McELI functions:

; *PART-OF-SPEECH* --- The current part of speech.
; *CD-FORM* --- The current conceptual dependency form.
; *SUBJECT* --- The CD form for the subject of the sentence.
; *PREDICATES* --- The list of predicates used in a noun phrase.
     
(def-word '*start*
   '((assign *part-of-speech* '()
             *cd-form* '()
             *subject* '()
             *predicates* '())
     (next-packet
       ((test (equal? *part-of-speech* 'noun-phrase))
        (assign *subject* *cd-form*)
        (next-packet
           ((test (equal? *part-of-speech* 'verb))
            (assign *concept* *cd-form*)))))))



; Utilities shared with micro SAM.
;----------------------------------------------------------------------

; CDs are lists with a header and pairs of (role-name filler).

(define header:cd
   (lambda (cd) (car cd)))

(define roles:cd
   (lambda (cd) (cdr cd)))

(define filler:pair
   (lambda (role-pair) (cadr role-pair)))

(define (role:pair role-pair)
   (car role-pair))

(define (filler:role role cd)
   (let ((assoc-pair (assoc role (roles:cd cd))))
      (if assoc-pair
          (cadr assoc-pair)
          '())))


; Variables have the form (*var* name)

(define (is-var? x)
   (and (pair? x) (eq? (car x) '*var*)))

(define (name:var x)
   (cadr x))

