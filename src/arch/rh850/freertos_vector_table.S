.section ".text", "ax"

.extern _start
.extern _vExceptionHandler
.extern _vInterruptHandler

.balign	0x200
.global _freertos_vector_table

_freertos_vector_table:
    /* Exceptions */
	jr	_start // RESET

	.balign	16
	syncp
	jr	_vExceptionHandler // SYSERR

	.balign	16
	jr	_vExceptionHandler // (R.F.U)

	.balign	16
	jr	_vExceptionHandler // FETRAP

	.balign	16
	jr	_vExceptionHandler // TRAP0

	.balign	16
	jr	_vExceptionHandler // TRAP1

	.balign	16
	jr	_vExceptionHandler // RIE

	.balign	16
	syncp
	jr	_vExceptionHandler // FPP/FPI

	.balign	16
	jr	_vExceptionHandler // UCPOP

	.balign	16
	jr	_vExceptionHandler // MIP/MDP

	.balign	16
	jr	_vExceptionHandler // RIE

	.balign	16
	jr	_vExceptionHandler // PIE

	.balign	16
	jr	_vExceptionHandler // MAE

	.balign	16
	jr	_vExceptionHandler // UCPOP

	.balign	16
	syncp
	jr	_vExceptionHandler // FENMI

	.balign	16
	syncp
	jr	_vExceptionHandler // FEINT

	/* Interrupts (EBASE.DV=1) */
	.balign	16
	syncp
	jr	_vInterruptHandler // INTn(priority0)

	.balign	16
	syncp
	jr	_vInterruptHandler // INTn(priority1)

	.balign	16
	syncp
	jr	_vInterruptHandler // INTn(priority2)

	.balign	16
	syncp
	jr	_vInterruptHandler // INTn(priority3)

	.balign	16
	syncp
	jr	_vInterruptHandler // INTn(priority4)

	.balign	16
	syncp
	jr	_vInterruptHandler // INTn(priority5)

	.balign	16
	syncp
	jr	_vInterruptHandler // INTn(priority6)

	.balign	16
	syncp
	jr	_vInterruptHandler // INTn(priority7)

	.balign	16
	syncp
	jr	_vInterruptHandler // INTn(priority8)

	.balign	16
	syncp
	jr	_vInterruptHandler // INTn(priority9)

	.balign	16
	syncp
	jr	_vInterruptHandler // INTn(priority10)

	.balign	16
	syncp
	jr	_vInterruptHandler // INTn(priority11)

	.balign	16
	syncp
	jr	_vInterruptHandler // INTn(priority12)

	.balign	16
	syncp
	jr	_vInterruptHandler // INTn(priority13)

	.balign	16
	syncp
	jr	_vInterruptHandler // INTn(priority14)

	.balign	16
	syncp
	jr	_vInterruptHandler // INTn(priority15)