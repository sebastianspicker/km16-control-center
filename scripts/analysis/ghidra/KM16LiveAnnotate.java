// Annotation pass for the acquired live image; no device access.
//@category KM16
import ghidra.app.script.GhidraScript;
import ghidra.program.model.listing.Function;
import ghidra.program.model.symbol.SourceType;
import java.nio.file.*;

public class KM16LiveAnnotate extends GhidraScript {
 public void run() throws Exception {
  Function reset=getFunctionAt(toAddr(0x0800b0fcL));
  reset.setNoReturn(true);
  for(String line:Files.readAllLines(Path.of(getScriptArgs()[0]))) {
   if(line.startsWith("address\t") || line.isBlank()) continue;
   String[] fields=line.split("\t",3);
   var address=toAddr(Long.parseLong(fields[0],16));
   Function function=getFunctionAt(address);
   if(function==null) { disassemble(address); function=createFunction(address,fields[1]); }
   if(function==null) throw new IllegalStateException("Missing function: "+fields[0]);
   function.setName(fields[1],SourceType.USER_DEFINED);
   function.setComment("Analyst interpretation of acquired device application, SHA256 5ff18a34b99de0e6ebb657f9f79df8e35a8b8e21459997096c24209bc493262e. "+fields[2]);
  }
  println("Live functions annotated; reset marked no-return; raw HID sender defined explicitly");
 }
}
