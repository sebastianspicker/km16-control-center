// Initialise a derived application image for static analysis; no device access.
//@category KM16
import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.*;
import ghidra.program.model.data.*;
import ghidra.program.model.lang.Register;
import ghidra.program.model.mem.*;
import ghidra.program.model.symbol.SourceType;
import java.math.BigInteger;

public class KM16Init extends GhidraScript {
 public void run() throws Exception {
  Memory memory=currentProgram.getMemory();
  Address start=toAddr(0x08002000L), end=memory.getMaxAddress();
  Register thumb=currentProgram.getRegister("TMode");
  currentProgram.getProgramContext().setValue(thumb,start,end,BigInteger.ONE);
  // Analysis windows only: their size does not assert physical RAM/peripheral size.
  memory.createUninitializedBlock("RAM_analysis_window",toAddr(0x20000000L),0x10000,false);
  memory.createUninitializedBlock("PERIPHERALS_analysis_window",toAddr(0x40000000L),0x24000,false);
  memory.createUninitializedBlock("CORTEX_system_analysis_window",toAddr(0xe000e000L),0x2000,false);
  createLabel(start,"application_vector_table",true);
  for(int i=0;i<0x160/4;i++) {
   Address slot=start.add(i*4);
   createDWord(slot);
   long ptr=Integer.toUnsignedLong(memory.getInt(slot));
   if(i>0 && (ptr&1)==1 && ptr>=0x08002160L && ptr<=end.getOffset()) {
    Address target=toAddr(ptr&~1L);
    if(getFunctionAt(target)==null) {
     disassemble(target);
     createFunction(target,i==1?"Reset_Handler":i==2?"Default_Handler":"Vector_"+i);
    }
    currentProgram.getSymbolTable().addExternalEntryPoint(target);
   }
  }
  Address startup=toAddr(0x08002160L);
  disassemble(startup); createFunction(startup,"cortex_startup");
  currentProgram.getSymbolTable().addExternalEntryPoint(startup);
  println("KM16 vectors and Thumb context initialised; ROM ends "+end);
 }
}
