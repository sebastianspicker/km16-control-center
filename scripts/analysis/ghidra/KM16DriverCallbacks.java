// Recover function entries from inspected USB, flash, and channel callback tables.
// Run only on a copy of the live-image project, never a hardware target.
//@category KM16
import ghidra.app.script.GhidraScript;
import ghidra.program.model.symbol.*;

public class KM16DriverCallbacks extends GhidraScript {
 public void run() throws Exception {
  long[][] ranges={{0x0800f684L,4},{0x0800f8c8L,8},
                   {0x0800f98cL,9},{0x0800f9b4L,9}};
  int added=0;
  for(long[] range:ranges) {
   for(int i=0;i<range[1];i++) {
    var cell=toAddr(range[0]+4L*i);
    long value=Integer.toUnsignedLong(currentProgram.getMemory().getInt(cell));
    if((value&1)==0 || value<0x08002160L || value>=0x0800eb00L)
      throw new IllegalArgumentException("Unexpected callback pointer at "+cell);
    var target=toAddr(value&~1L);
    if(getFunctionAt(target)==null) {
     disassemble(target);
     if(createFunction(target,"driver_callback_"+target)==null)
       throw new IllegalStateException("Cannot create callback at "+target);
     added++;
    }
    currentProgram.getReferenceManager().addMemoryReference(cell,target,
      RefType.DATA,SourceType.USER_DEFINED,-1);
    currentProgram.getSymbolTable().addExternalEntryPoint(target);
   }
  }
  // keyboard_setup (0x08006200) installs this pointer as its character output hook.
  var consoleCell=toAddr(0x08006218L);
  long consolePointer=Integer.toUnsignedLong(currentProgram.getMemory().getInt(consoleCell));
  if(consolePointer!=0x0800b811L) throw new IllegalArgumentException("Unexpected console hook");
  var consoleTarget=toAddr(consolePointer&~1L);
  if(getFunctionAt(consoleTarget)==null) {
   disassemble(consoleTarget); createFunction(consoleTarget,"console_enqueue_character"); added++;
  }
  currentProgram.getReferenceManager().addMemoryReference(consoleCell,consoleTarget,
    RefType.DATA,SourceType.USER_DEFINED,-1);
  currentProgram.getSymbolTable().addExternalEntryPoint(consoleTarget);
  analyzeChanges(currentProgram);
  println("Recovered "+added+" additional callback entries from inspected tables.");
 }
}
