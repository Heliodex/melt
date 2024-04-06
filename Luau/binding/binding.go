package luau

//#include "tree_sitter/parser.h"
//TSLanguage *tree_sitter_luau();
import "C"
import (
	"unsafe"

	sitter "github.com/smacker/go-tree-sitter"
)

func GetLuau() *sitter.Language {
	ptr := unsafe.Pointer(C.tree_sitter_luau())
	return sitter.NewLanguage(ptr)
}
