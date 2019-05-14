.data 	0x10000000

	filename:			.asciiz		"source.bmp" #"inputFileTest.txt" 
	header: 			.space 		54
	
	fileOpenError:			.asciiz 	"Cannot open the file.\n"
	fileReadError:			.asciiz 	"Cannot read the file.\n"
	fileFormatError:		.asciiz 	"File format is not supported\n"
	
	fileOpenSuccess:		.asciiz 	"File was opened successfully.\n"
	fileReadSuccess:		.asciiz 	"File was read successfully.\n"
	
	strPrintHistogramHyphen: 	.asciiz 	"\t - \t"
	strPrintHistogramHeader: 	.asciiz 	"Image Histogram: \n\n   |  Intensity  |  Ocurrences  | \n\t"
	strHistogramHr: 		.asciiz 	" \n\t"
	
	imgBre:				.asciiz 	"\nbre\n"
	imgCar:				.asciiz 	"\ncar\n"
	imgLin:				.asciiz 	"\nlin\n"
	imgNotFound:			.asciiz 	"\nInput image not found.\n"	
		
.text

	Main:
	# Open the file.
		la $a0, filename 
		li $a1, 0 # Read only flag.
		li $a2, 0 # Mode is ignored.
		
		li $v0, 13 # Open file syscall 13.
			syscall
			
		move $s0, $v0 # Save the file descriptor.
			
	# Handle open error 
		bltz $s0, openFileError
		
		la $a0, fileOpenSuccess
		
		li $v0, 4
			syscall
			
	# Read the file. 
		move $a0, $s0 # File descriptor.
		
	# Read bmp file 54 bytes header
		la $a1, header # Address of the space to copy the file header
		li $a2, 54 # No. of bytes to read
		jal readHeader

	# Handle read error 
		bltz $v0, readFileError
		
		la $a0, fileReadSuccess
		
		li $v0, 4
			syscall		
			
	# Determine whether input file is bmp based on values in header.
		jal analyseHeader 
		move $s1, $v0 # Starting address of img info 0($s1) - size, 4($s2) - width, 8($s3) - height
		move $s2, $v1 # Starting address of pixels value (ints)
	
	# Save bit-map on stack		
		jal storeImage # store rest(pixels values) of bmp file at stack ($t9)
		
	# Close file. 
		move $a0, $s0 # File descriptor.
		jal closeFile
			
		la $a0, 0($s1)	
		la $a1, 0($s2)
		jal histogram
 		move $s3, $v0 # Save value of mode.
		
		
		move $a0, $s3
		jal isBre
		jal isCar
		jal isLin
		
		la $a0, imgNotFound
		li $v0, 4
			syscall
		
	Exit: # Terminate execution.
		li $v0, 10
			syscall
			
#------------------------>> Functions <<------------------------#			
			
	openFileError:
		la $a0, fileOpenError
		
		li $v0, 4
			syscall
			
		j Exit
		
	readFileError:
		la $a0, fileReadError
		
		li $v0, 4
			syscall
			
		jal closeFile
			
		j Exit
		
	wrongFileFormat:	
		la $a0, fileFormatError
		
		li $v0, 4
			syscall
			
		j Exit
		
	closeFile:
		li $v0, 16
			syscall	
		jr $ra
		
	readHeader:		
		li $v0, 14			
			syscall	
						
		bltz $v0, readFileError
		jr $ra
		
	analyseHeader:
		la $t0, header

	# fileHeaderCheck
		# The first 2 bytes are suposed to be (424d)h
		lb $t1, 0($t0)	# Should be (42)h
		lb $t2, 1($t0)	# Should be (4D)h
		
		bne $t1, 0x42, wrongFileFormat
		bne $t2, 0x4d, wrongFileFormat

		# The 7th, 8th, 9th and 10th bytes are reserved and suposed to be 0
		# Since memory is zero-indexed we start by the address of number 6
		lb $t1, 6($t0)
		lb $t2, 7($t0)
		lb $t3, 8($t0)
		lb $t4, 9($t0)
		bne $t1, $zero, wrongFileFormat
		bne $t2, $zero, wrongFileFormat
		bne $t3, $zero, wrongFileFormat
		bne $t4, $zero, wrongFileFormat

		# Since we are dealing with a True Color bmp image, we should check if the
		# BfOffSetBits field is (54)d as expected.
		lb $t1, 10($t0)
		bne $t1, 54, wrongFileFormat
	# end fileHeaderCheck

	# bitmapHeaderCheck
		# Checking BiSize field that has a fixed value of (40)d
		lb $t1, 14($t0)
		bne $t1, 40, wrongFileFormat

		# Checking the BiPlane field that has a fixed value of (1)d
		lb $t1, 26($t0)
		bne $t1, 1, wrongFileFormat

		# Checking BiBitCount field, that says how much bits a pixel need
		# If more or less than 24 the program will abort.
		lb $t1, 28($t0)
		bne $t1, 24, wrongFileFormat

		# Checking BiCompress field, which must be zero
		lb $t1, 30($t0)
		bne $t1, 0, wrongFileFormat
	# end bitmapHeaderCheck

		addi $sp, $sp, -12
		add $t8, $sp, $zero

		# loadWidth
		lwr $t1, 21($t0)
		lwr $t1, 20($t0)
		lwr $t1, 19($t0)
		lwr $t1, 18($t0)
		
		# loadHeight	
		#lwr $t2, 25($t0)
		lwr $t2, 24($t0)
		lwr $t2, 23($t0)
		lwr $t2, 22($t0) 		

		# loadSize	
		lwr $t3, 37($t0)
		lwr $t3, 36($t0)
		lwr $t3, 35($t0)
		lwr $t3, 34($t0)
		
		sw $t3, 0($t8)								
		sw $t1, 4($t8)		
		sw $t2, 8($t8)		

		# Allocate the size of the bitmap of the image in bytes at the stack.
		sub $sp, $sp, $t3
		add $t9, $sp, $zero
		
		move $v0, $t8 # address of sp to img info.
		move $v1, $t9 # address of sp to pixels value.
		
		jr $ra
		
	storeImage:
		move $a0, $s0 # File descriptor.
		add $a1, $s2, $zero
		lw $a2, 0($s1)	
	
		li $v0, 14		
			syscall		
					
		blt $v0, $zero, readFileError
		
		jr $ra

	histogram:
		add $t0, $a0, $zero 		# $t0: img info 
		add $t1, $a1, $zero		# $t1: starting address of pixels values
	
		add $sp, $sp, -1028		# Allocate space for histogram (256 int - 256*4)
		add $t2, $sp, $zero 		# $t2: stack frame base address
	
		li $t3, 0			# $t3: iteration index
		# Dimensions
		lw $t4, 4($t0)			
		lw $t5, 8($t0)
	
		mul $t4, $t4, $t5		# $t4: max number of iterations
	
		li $t8, 0			# Register to store mode. 
		li $t0, 0 			# $t0 - is not required anymore, it may be assigned to store another value.
	
		add $t1, $t1, 2			# Set address to first red pixel value
		sub $t4, $t4, 2			# Decrease max iterations 
		
		loop_histogram:
			beq $t3, $t4, end_looop_histogram 
			# Write read value to the stack $t2
		
			lbu $t5, 0($t1) # Read pixel's value	
			 # Find it's reference in stack
			mul $t5, $t5, 4 
			add $t7, $t2, $t5
		
			lw $t6, 0($t7) # $t6: retrieved stored quantity 
			add $t6, $t6, 1 # increase occurance of Intensity
			sw $t6, 0($t7) # save new value

			sub $t5, $t0, $t6
			bgez $t5, noChange
				lw $t0, 0($t7) # Save occurance 
				lbu $t8, 0($t1) # Save intensity
			
			noChange:	
				add $t1, $t1, 3
				add $t3, $t3, 1
		j loop_histogram
	end_looop_histogram:

	#la $a0, ($t0)
	#li $v0, 1
	#	syscall

	#la $a0, ($t8)
	#li $v0, 1
	#	syscall

	# add $a0, $t2, $zero
	# add $t9, $ra, $zero
	
	# jal printHistogram
	
	# add $ra, $t9, $zero
	# add $sp, $sp, 1028
	
	move $v0, $t8 
	jr $ra

	printHistogram:
	# input address of sp to histogram
		add $t0, $a0, $zero # Starting address of red component histogram.
				
		li $t1, 0 # loop index									
		li $t2, 256 # max index					

		# print header
		la $a0, strPrintHistogramHeader
		li $v0, 4
			syscall

		loop_printHistogram:
			beq $t1, $t2, end_loop_printHistogram
			lw $t3, 0($t0)			

			add $a0, $t1, $zero
			li $v0, 1
				syscall

			la $a0, strPrintHistogramHyphen
			li $v0, 4
				syscall

			add $a0, $t3, $zero
			li $v0, 1
				syscall

			la $a0, strHistogramHr
			li $v0, 4
				syscall

			add $t1, $t1, 1	# increase loop index		
			add $t0, $t0, 4 # go to next int 
			j loop_printHistogram
		end_loop_printHistogram:

		jr $ra
		
	isBre: # determine if img is bre-x, input mode value.
		add $t0, $a0, $zero # Copy mode
		 	
		blt $t0, 185, notBre
		bgt $t0, 190, notBre
		
		bre: # is Bre prompt.
			la $a0, imgBre
			li $v0, 4
				syscall
				
			j Exit
		
		notBre:
			jr $ra
			
	isLin: # determine if img is lin-x, input mode value.
		add $t0, $a0, $zero # Copy mode
		 	
		blt $t0, 99, notLin
		bgt $t0, 114, notLin
		
		lin: # is Lin prompt.
			la $a0, imgLin
			li $v0, 4
				syscall
				
			j Exit
		
		notLin:
			jr $ra
			
	isCar: # determine if img is car-x, input mode value.
		add $t0, $a0, $zero # Copy mode
		 	
		blt $t0, 205, notCar
		bgt $t0, 216, notCar
		
		car: # is Car prompt.
			la $a0, imgCar
			li $v0, 4
				syscall
				
			j Exit
		
		notCar:
			jr $ra
		

			
					
			
		
		
		
		
