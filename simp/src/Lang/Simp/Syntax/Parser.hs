{-# LANGUAGE MultiParamTypeClasses #-}
{-# OPTIONS_GHC -Wno-unrecognised-pragmas #-}
{-# HLINT ignore "Use lambda-case" #-}
{-# HLINT ignore "Use <$>" #-}
module Lang.Simp.Syntax.Parser where


import Lang.Simp.Syntax.Parsec
import Lang.Simp.Syntax.SrcLoc
import Lang.Simp.Syntax.AST ( Const(..), Exp(..), Var(..), Stmt(..) )
import Lang.Simp.Syntax.Lexer

-- | The `PEnv` datatype defines a parser environment
newtype PEnv = PEnv {
    toks :: [LToken]
}

-- | check whether the parsing is done based on the list of tokens left. 
done :: PEnv -> Bool
done penv = null $ toks penv

instance ParserEnv PEnv LToken where
    getCol penv = case toks penv of
        { [] -> -1
        ; (tok:_) -> case srcLoc tok of
            { SrcLoc ln col -> col }
        }
    getLine penv = case toks penv of
        { [] -> -1
        ; (tok:_) -> case srcLoc tok of
            { SrcLoc ln col -> ln }
        }
    setTokens ts penv = penv{toks = ts}
    setLine ln penv = penv --  "setLine for PEnv has no write permission."
    setCol col penv = penv --  "setCol for PEnv ihas no write permission."
    isNextTokNewLine penv = case getTokens penv of
           { ((WhiteSpace _ c):_) ->  c == '\n'
           ; _ -> False
           }
    getTokens = toks


-- | The function `parser` is the top level parsing function; 
parser :: Parser PEnv [Stmt]
parser = pStmts

-- | The function `pStmts` parses zero or more statements separated by some spaces.
pStmts :: Parser PEnv [Stmt]
pStmts = many pOne
    where
        pOne = do
        { pSpaces
        ; s <- pStmt
        ; pSpaces
        ; return s
        }

-- | The function `pStmt` parses one statement 
pStmt :: Parser PEnv Stmt
pStmt = choice pAssign (choice pRet (choice pNop (choice pIfElse pWhile)))

-- | The function `pNop` parses a nop statement 
pNop :: Parser PEnv Stmt
pNop = do
    _ <- sat (\tok -> case tok of { NopKW src -> True ; _ -> False}) "expecting a NOP keyword but none is found."
    pSpaces
    pSemiColon
    return Nop

-- | The function `pAssign` parses an assignment statement 
pAssign :: Parser PEnv Stmt
pAssign = do
    x <- pVar
    pSpaces
    pEqual
    pSpaces
    e <- pExp
    pSpaces
    pSemiColon
    return (Assign x e)

-- | The function `pRet` parses a return statement
pRet :: Parser PEnv Stmt
pRet = do
    pReturnKW
    pSpaces
    x <- pVar
    pSpaces
    pSemiColon
    return (Ret x)


-- | The function`pIfElse` parses an if-else statement
pIfElse :: Parser PEnv Stmt
pIfElse = do
    pIfKW
    pSpaces
    e <- pExp
    pSpaces
    pLBrace
    s1 <- pStmts
    pRBrace
    pSpaces
    pElseKW
    pSpaces
    pLBrace
    s2 <- pStmts
    pRBrace
    return (If e s1 s2)

pWhile :: Parser PEnv Stmt
pWhile = do
    pWhileKW
    pSpaces
    e <- pExp
    pLBrace
    s <- pStmts
    pRBrace
    return (While e s)


-- Lab 1 Task 1.1 

-- | the `pSpace` function parses / skips a space token
pSpace :: Parser PEnv LToken
pSpace = sat (\x -> case x of
                (WhiteSpace _ _) -> True
                _ -> False
            ) "Expecting one whitespace!"

-- | The `pSpaces` function parses / skips zero or more space tokens
pSpaces :: Parser PEnv [LToken]
pSpaces = many pSpace

-- Lab 1 Task 1.1 end 


-- Lab 1 Task 1.2 
--     Parsing an expression
--     Note that 
--     E ::= E Op E | X | C | (E) contains left recursion


--     << Left Recursion Eliminated >>
--     << Grammar >>
--     E  = X E'
--     E  = C E'
--     E  = (E) E'
--     E' = OP E E'
--     E' = Epsilon

-- Helper function to parse a token and skip spaces after it
tokenWithSpaces :: Parser PEnv a -> Parser PEnv a
tokenWithSpaces p = do
    result <- p
    _ <- pSpaces
    return result


data ExpLE = VarExpLE Var ExpLEP
    | ConstExpLE Const ExpLEP
    | ParenExpLE ExpLE ExpLEP

data ExpLEP = PlusLE ExpLE ExpLEP
    | MinusLE ExpLE ExpLEP
    | MultLE ExpLE ExpLEP
    | DEqualLE ExpLE ExpLEP
    | LThanLE ExpLE ExpLEP
    | NIL

pExp :: Parser PEnv Exp
pExp = do
    exple <- pExpLE
    return (fromExpLE exple)

pExpLE :: Parser PEnv ExpLE
pExpLE = choice pVarExpLE (choice pConstExpLE pParenExpLE)

pVarExpLE :: Parser PEnv ExpLE
pVarExpLE = do
    var <- tokenWithSpaces pVar
    e'  <- pExpLEP
    return (VarExpLE var e')

pConstExpLE :: Parser PEnv ExpLE
pConstExpLE = do 
    c  <- tokenWithSpaces pConst
    e' <- pExpLEP
    return (ConstExpLE c e')

pParenExpLE :: Parser PEnv ExpLE
pParenExpLE = do
    _  <- tokenWithSpaces pLParen
    e  <- pExpLE
    _  <- tokenWithSpaces pRParen
    e' <- pExpLEP
    return (ParenExpLE e e')

pExpLEP :: Parser PEnv ExpLEP
pExpLEP = choice pPlusLE (
    choice pMinusLE (
        choice pMultLE (
            choice pDEqualLE (
                choice pLThanLE pNIL))))

pPlusLE :: Parser PEnv ExpLEP
pPlusLE = do 
    _ <- tokenWithSpaces pPlus
    e <- pExpLE
    e' <- pExpLEP
    return (PlusLE e e')

pMinusLE :: Parser PEnv ExpLEP
pMinusLE = do
    _  <- tokenWithSpaces pMinus
    e  <- pExpLE
    e' <- pExpLEP
    return (MinusLE e e')

pMultLE :: Parser PEnv ExpLEP
pMultLE = do 
    _  <- tokenWithSpaces pMult
    e  <- pExpLE
    e' <- pExpLEP
    return (MultLE e e')

pDEqualLE :: Parser PEnv ExpLEP
pDEqualLE = do
    _  <- tokenWithSpaces pDEqual
    e  <- pExpLE
    e' <- pExpLEP
    return (DEqualLE e e')

pLThanLE :: Parser PEnv ExpLEP
pLThanLE = do
    _  <- tokenWithSpaces pLThan
    e  <- pExpLE
    e' <- pExpLEP
    return (LThanLE e e')

pNIL :: Parser PEnv ExpLEP
pNIL = empty NIL

fromExpLE :: ExpLE -> Exp
fromExpLE (VarExpLE x expP) = fromExpLEP (VarExp x) expP 
fromExpLE (ConstExpLE c expP) = fromExpLEP (ConstExp c) expP
fromExpLE (ParenExpLE e expP) = fromExpLEP (ParenExp (fromExpLE e)) expP

fromExpLEP :: Exp -> ExpLEP -> Exp
fromExpLEP exp (PlusLE exp2 expP) = fromExpLEP (Plus exp (fromExpLE exp2)) expP
fromExpLEP exp (MinusLE exp2 expP) = fromExpLEP (Minus exp (fromExpLE exp2)) expP
fromExpLEP exp (MultLE exp2 expP) = fromExpLEP (Mult exp (fromExpLE exp2)) expP
fromExpLEP exp (DEqualLE exp2 expP) = fromExpLEP (DEqual exp (fromExpLE exp2)) expP
fromExpLEP exp (LThanLE exp2 expP) = fromExpLEP (LThan exp (fromExpLE exp2)) expP
fromExpLEP exp NIL = exp


--------------------------

-- Lab 1 Task 1.2 end 


pPlus :: Parser PEnv LToken
pPlus = sat (\tok -> case tok of
    { PlusSign _ -> True
    ; _ -> False
    }) "expecting a + token but none is found."


pMinus :: Parser PEnv LToken
pMinus = sat (\tok -> case tok of
    { MinusSign _ -> True
    ; _ -> False
    }) "expecting a - token but none is found."


pMult :: Parser PEnv LToken
pMult = sat (\tok -> case tok of
    { AsterixSign _ -> True
    ; _ -> False
    }) "expecting a * token but none is found."


pLThan :: Parser PEnv LToken
pLThan = sat (\tok -> case tok of
    { LThanSign _ -> True
    ; _ -> False
    }) "expecting a < token but none is found."


pDEqual :: Parser PEnv LToken
pDEqual = sat (\tok -> case tok of
    { DEqSign _ -> True
    ; _ -> False
    }) "expecting a == token but none is found."


pEqual :: Parser PEnv LToken
pEqual = sat (\tok -> case tok of
    { EqSign _ -> True
    ; _ -> False
    }) "expecting a = token but none is found."



pVar :: Parser PEnv Var
pVar = do
    tok <- sat (\tok -> case tok of
        { IdTok src v -> True
        ; _ -> False
        }) "expecting an identifier but none is found."
    name <- justOrFail tok (\t-> case t of
        { IdTok src v -> Just v
        ; _ -> Nothing
        }) "expecting an identifier but none is found."
    return (Var name)

pConst :: Parser PEnv Const
pConst = choice pTrue (choice pFalse pInt)


pTrue :: Parser PEnv Const
pTrue = do
    tok <- sat (\tok -> case tok of
        { TrueKW src -> True
        ; _ -> False
        }) "expecting a true keyword but none is found."
    return (BoolConst True)



pFalse :: Parser PEnv Const
pFalse = do
    tok <- sat (\tok -> case tok of
        { FalseKW src -> True
        ; _ -> False
        }) "expecting a false keyword but none is found."
    return (BoolConst False)


pInt :: Parser PEnv Const
pInt = do
    tok <- sat (\tok -> case tok of
        { IntTok src v -> True
        ; _ -> False
        }) "expecting an integer but none is found."
    i <- justOrFail tok (\t -> case t of
        { IntTok srv v -> Just v
        ; _ -> Nothing
        }) "expecting an integer but none is found."
    return (IntConst i)


-- parsing keywords 

pReturnKW :: Parser PEnv LToken
pReturnKW = sat (\tok -> case tok of
    { RetKW src -> True
    ; _ -> False
    }) "expecting a return keyword but none is found."

pIfKW :: Parser PEnv LToken
pIfKW = sat (\tok -> case tok of
    { IfKW src -> True
    ; _ -> False
    }) "expecting an if keyword but none is found."

pElseKW :: Parser PEnv LToken
pElseKW = sat (\tok -> case tok of
    { ElseKW src -> True
    ; _ -> False
    }) "expecting an else keyword but none is found."


pWhileKW :: Parser PEnv LToken
pWhileKW = sat (\tok -> case tok of
    { WhileKW src -> True
    ; _ -> False
    }) "expecting a while keyword but none is found."


-- parsing symbols

pLBrace :: Parser PEnv LToken
pLBrace = sat (\tok -> case tok of
    { LBrace src -> True
    ; _ -> False
    }) "expecting a { but none is found."



pRBrace :: Parser PEnv LToken
pRBrace = sat (\tok -> case tok of
    { RBrace src -> True
    ; _ -> False
    }) "expecting a } but none is found."


pLParen :: Parser PEnv LToken
pLParen = sat (\tok -> case tok of
    { LParen src -> True
    ; _ -> False
    }) "expecting a ( but none is found."



pRParen :: Parser PEnv LToken
pRParen = sat (\tok -> case tok of
    { RParen src -> True
    ; _ -> False
    }) "expecting a ) but none is found."


pSemiColon :: Parser PEnv LToken
pSemiColon = sat (\tok -> case tok of
    { SemiColon src -> True
    ; _ -> False
    }) "expecting a ; but none is found."
