//@category KM16
import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.*;
import ghidra.program.model.listing.*;
import ghidra.program.model.symbol.*;
import java.io.*;
import java.nio.charset.StandardCharsets;

public class KM16Export extends GhidraScript {
 public void run() throws Exception {
  File directory=new File(getScriptArgs()[0]); directory.mkdirs();
  DecompInterface decomp=new DecompInterface();decomp.openProgram(currentProgram);
  int count=0, failed=0;
  try(PrintWriter index=new PrintWriter(new File(directory,"functions.tsv"),StandardCharsets.UTF_8);
      PrintWriter refs=new PrintWriter(new File(directory,"references.tsv"),StandardCharsets.UTF_8)) {
   index.println("entry\tname\tsize\tdecompiled");
   refs.println("from\tto\ttype\tfunction");
   FunctionIterator functions=currentProgram.getFunctionManager().getFunctions(true);
   while(functions.hasNext() && !monitor.isCancelled()) {
    Function f=functions.next();
    DecompileResults result=decomp.decompileFunction(f,30,monitor);
    String address=f.getEntryPoint().toString();
    boolean ok=result.decompileCompleted() && result.getDecompiledFunction()!=null;
    index.println(address+"\t"+f.getName()+"\t"+f.getBody().getNumAddresses()+"\t"+ok);
    try(PrintWriter output=new PrintWriter(new File(directory,address+".c"),StandardCharsets.UTF_8)) {
     output.println("// "+address+" "+f.getName()+"; automatically recovered C, not original source");
     if(ok) output.println(result.getDecompiledFunction().getC());
     else {failed++;output.println("// Decompilation failed: "+result.getErrorMessage());}
    }
    InstructionIterator instructions=currentProgram.getListing().getInstructions(f.getBody(),true);
    try(PrintWriter output=new PrintWriter(new File(directory,address+".asm"),StandardCharsets.UTF_8)) {
     while(instructions.hasNext()) {
      Instruction instruction=instructions.next();
      output.println(instruction.getAddress()+" "+instruction);
      for(Reference r:instruction.getReferencesFrom())
       refs.println(r.getFromAddress()+"\t"+r.getToAddress()+"\t"+r.getReferenceType()+"\t"+address);
     }
    }
    count++;
   }
  } finally {decomp.dispose();}
  println("Exported "+count+" functions; decompilation failures: "+failed);
 }
}
