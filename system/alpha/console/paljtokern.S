/*
 * Copyright (c) 2003-2004 The Regents of The University of Michigan
 * Copyright (c) 1993 The Hewlett-Packard Development Company
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met: redistributions of source code must retain the above copyright
 * notice, this list of conditions and the following disclaimer;
 * redistributions in binary form must reproduce the above copyright
 * notice, this list of conditions and the following disclaimer in the
 * documentation and/or other materials provided with the distribution;
 * neither the name of the copyright holders nor the names of its
 * contributors may be used to endorse or promote products derived from
 * this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include "dc21164FromGasSources.h"	// DECchip 21164 specific definitions
#include "ev5_defs.h"
#include "fromHudsonOsf.h"		// OSF/1 specific definitions
#include "fromHudsonMacros.h"		// Global macro definitions

/* Jump to kernel
 * args:
 *	Kernel address - a0
 *	PCBB           - a1
 *	First free PFN - a3?
 *
 *	Enable kseg addressing in ICSR
 *	Enable kseg addressing in MCSR
 *	Set VTBR -- Set to 1GB as per SRM, or maybe 8GB??
 *	Set PCBB -- pass pointer in arg
 *	Set PTBR -- get it out of PCB
 *	Set KSP  -- get it out of PCB
 *
 *	Jump to kernel address
 *
 *	Kernel args-
 *	s0 first free PFN
 *	s1 ptbr
 *	s2 argc 0
 *	s3 argv NULL
 *	s5 osf_param (sysconfigtab) NULL
 */

        .global palJToKern
        .text 3
palJToKern:
        ALIGN_BRANCH

        ldq_p	a0, 0(zero)
        ldq_p	a1, 8(zero)
        ldq_p	a3, 16(zero)

        /* Point the Vptbr at 8GB */
        lda	t0, 0x1(zero)
        sll	t0, 33, t0

        mtpr	t0, mVptBr	// Load Mbox copy
        mtpr	t0, iVptBr	// Load Ibox copy
        STALL			// don't dual issue the load with mtpr -pb

        /* Turn on superpage mapping in the mbox and icsr */
        lda	t0, (2<<MCSR_V_SP)(zero) // Get a '10' (binary) in MCSR<SP>
        STALL			// don't dual issue the load with mtpr -pb
        mtpr	t0, mcsr	// Set the super page mode enable bit
        STALL			// don't dual issue the load with mtpr -pb

        lda	t0, 0(zero)
        mtpr	t0, dtbAsn
        mtpr	t0, itbAsn

        LDLI	(t1,0x20000000)
        STALL			// don't dual issue the load with mtpr -pb
        mfpr	t0, icsr	// Enable superpage mapping
        STALL			// don't dual issue the load with mtpr -pb
        bis	t0, t1, t0
        mtpr	t0, icsr

        STALL			// Required stall to update chip ...
        STALL
        STALL
        STALL
        STALL

        ldq_p	s0, PCB_Q_PTBR(a1)
        sll	s0, VA_S_OFF, s0 // Shift PTBR into position
        STALL			// don't dual issue the load with mtpr -pb
        mtpr	s0, ptPtbr	// PHYSICAL MBOX INST -> MT PT20 IN 0,1
        STALL			// don't dual issue the load with mtpr -pb
        ldq_p	sp, PCB_Q_KSP(a1)

        mtpr	a0, excAddr	// Load the dispatch address.
        STALL			// don't dual issue the load with mtpr -pb
        bis	a3, zero, a0	// first free PFN
        ldq_p	a1, PCB_Q_PTBR(a1) // ptbr
        ldq_p	a2, 24(zero)	// argc
        ldq_p	a3, 32(zero)	// argv
        ldq_p	a4, 40(zero)	// environ
        lda	a5, 0(zero)	// osf_param
        STALL			// don't dual issue the load with mtpr -pb
        mtpr	zero, dtbIa	// Flush all D-stream TB entries
        mtpr	zero, itbIa	// Flush all I-stream TB entries
        br	zero, 2f

        ALIGN_BLOCK

2:      NOP
        mtpr	zero, icFlush	// Flush the icache.
        NOP
        NOP

        NOP			// Required NOPs ... 1-10
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP

        NOP			// Required NOPs ... 11-20
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP

        NOP			// Required NOPs ... 21-30
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP

        NOP			// Required NOPs ... 31-40
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP

        NOP			// Required NOPs ... 41-44
        NOP
        NOP
        NOP

        hw_rei_stall		// Dispatch to kernel
