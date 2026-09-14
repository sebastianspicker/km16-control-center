// Reproduce the live application's startup .data copy for static pointer analysis.
//@category KM16
import ghidra.app.script.GhidraScript;
import ghidra.program.model.mem.*;

public class KM16LiveData extends GhidraScript {
 public void run() throws Exception {
  Memory memory=currentProgram.getMemory();
  var start=toAddr(0x20000c00L);
  var end=toAddr(0x20000e54L);
  MemoryBlock block=memory.getBlock(start);
  if(!block.getStart().equals(start)) memory.split(block,start);
  block=memory.getBlock(start);
  if(block.getEnd().compareTo(end)>=0) memory.split(block,end);
  block=memory.getBlock(start);
  if(!block.isInitialized()) memory.convertToInitialized(block,(byte)0);
  block=memory.getBlock(start); block.setName("RAM_startup_data"); block.setWrite(true);
  byte[] bytes=new byte[0x254]; memory.getBytes(toAddr(0x0800fb5cL),bytes);
  memory.setBytes(start,bytes);
  // All entries below were inspected as actual function-pointer initializer cells.
  long[] cells={0x20000c00L,0x20000c04L,0x20000c08L,0x20000c0cL,0x20000c10L,
                0x20000cacL,0x20000d2cL,0x20000d54L,0x20000d74L,
                0x20000e38L,0x20000e3cL,0x20000e40L,0x20000e44L,0x20000e48L};
  for(long cell:cells) {
   var location=toAddr(cell);
   long pointer=Integer.toUnsignedLong(memory.getInt(location));
   var target=toAddr(pointer&~1L);
   if(getFunctionAt(target)==null) { disassemble(target); createFunction(target,"callback_"+target); }
   currentProgram.getReferenceManager().addMemoryReference(location,target,
      ghidra.program.model.symbol.RefType.DATA,
      ghidra.program.model.symbol.SourceType.USER_DEFINED,-1);
   currentProgram.getSymbolTable().addExternalEntryPoint(target);
  }
  analyzeChanges(currentProgram);
  println("Copied only startup .data initializer; recovered its callback entries. RAM is mutable, not a runtime snapshot.");
 }
}
