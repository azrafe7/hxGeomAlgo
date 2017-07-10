#if macro
import haxe.macro.ExprTools;
import haxe.macro.Printer;
import haxe.macro.Context;
import haxe.macro.Expr;
import sys.FileSystem;
#end

import haxe.Json;
import haxe.io.BytesInput;
import haxe.io.Path;
import haxe.macro.Compiler;
import hxPixels.Pixels;

#if hxPako
import pako.Deflate;
import pako.Pako;
import pako.zlib.Constants.ErrorStatus;
#end


typedef ManifestEntry = {
  var name:String;
  var metadata:Dynamic;
}

typedef ManifestType = {
  var assets:Array<ManifestEntry>;
}

class Embedder {
#if macro
  static public function embed(dir:String) {
    
    dir = Path.normalize(dir);
    var files = FileSystem.readDirectory(dir);
    files = files.filter(function (f) { return !FileSystem.isDirectory(f) && StringTools.endsWith(f.toLowerCase(), ".png"); } );
    
    var entries:Array<ManifestEntry> = [];
    var manifest:ManifestType = { assets:entries };
    
  #if (pako || hxPako)
    trace("hxPako");
  #end
    
    for (f in files) {
      //if (f.indexOf("pirate") < 0) continue;
      var asset = Path.join([dir, f]);
      var bytes = sys.io.File.getBytes(asset);
      trace(asset + " (" + bytes.length + ")");
      
      var entry:ManifestEntry = { name: asset, metadata: null };
      
      var pngReader = new format.png.Reader(new BytesInput(bytes));
      var data = pngReader.read();
      var pixels = Pixels.fromPNGData(data);
      pixels.convertTo(PixelFormat.RGBA);
      trace("pixels " + asset + " (" + pixels.uint8Array.length + ")");
      
      /*var deflator = new Deflate();
      deflator.push(haxe.io.UInt8Array.fromBytes(pixels.bytes), true);
      
      if (deflator.err != ErrorStatus.Z_OK) trace("ERROR: " + deflator.msg);
      var compressed = deflator.result;
      
      trace("pixels " + asset + " (" + pixels.uint8Array.length + ")");
      trace("pako   " + asset + " (" + compressed.length + ")");
      Context.addResource(asset, compressed.view.buffer);
      */
      var compressed = haxe.zip.Compress.run(pixels.bytes, 9);
      trace("haxe   " + asset + " (" + compressed.length + ")");
      Context.addResource(asset, compressed);
      
      entry.metadata = { 
        width: pixels.width,
        height: pixels.height
      };
      entries.push(entry);
    }
    
    trace(manifest);
    Context.addResource("manifest.json", haxe.io.Bytes.ofString(Json.stringify(manifest)));
  }
  
  static public function build(dir:String):Array<Field> {
    var fields = Context.getBuildFields();
    
    var asset = "project.xml";
    var bytes = sys.io.File.getBytes(asset);
    trace(asset + " (" + bytes.length + ")");
    //Context.addResource(asset, bytes);
    
    return fields;
  }
#end
}