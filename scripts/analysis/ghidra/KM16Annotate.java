// Applies analyst-assigned names to the reference image only.
//@category KM16
import ghidra.app.script.GhidraScript;
import ghidra.program.model.listing.Function;
import ghidra.program.model.symbol.SourceType;
import java.nio.file.*;

public class KM16Annotate extends GhidraScript {
 public void run() throws Exception {
  int count=0;
  for(String line:Files.readAllLines(Path.of(getScriptArgs()[0]))) {
   if(line.startsWith("address\t") || line.isBlank()) continue;
   String[] fields=line.split("\t",3);
   Function function=getFunctionAt(toAddr(Long.parseLong(fields[0],16)));
   if(function==null) throw new IllegalStateException("Missing function: "+fields[0]);
   function.setName(fields[1],SourceType.USER_DEFINED);
   function.setComment("Analyst interpretation of supplied V0101 reference image, not connected-board verification. "+fields[2]);
   count++;
  }
  println("Annotated "+count+" reference-image functions");
 }
}
