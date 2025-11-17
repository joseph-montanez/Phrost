// HashTable * function_table = (((zend_executor_globals * )(((char * ) tsrm_get_ls_cache()) + (executor_globals_offset))) -> function_table);
// zend_string * func_name;
// zval * zv;

// HashTable * __ht = (function_table);
// zend_ulong __h;
// zend_string * __key = __null;
// uint32_t _idx = (0);
// size_t _size = (sizeof(zval) + (~(__ht) -> u.flags & (1 << 2)) * ((sizeof(Bucket) - sizeof(zval)) / (1 << 2)));
// zval * __z = ((zval * )(((char * )(__ht) -> arPacked) + ((_idx) * (_size))));
// uint32_t _count = __ht -> nNumUsed - _idx;
// for (; _count > 0; _count--) {
// zval * _z = __z;
// if ((((__ht) -> u.flags & (1 << 2)) != 0)) {
//     __z++;
//     __h = _idx;
//     _idx++;
// } else {
//     Bucket * _p = (Bucket * ) __z;
//     __z = & (_p + 1) -> val;
//     __h = _p -> h;
//     __key = _p -> key;
//     if (0 && zval_get_type( & ( * (_z))) == 12) {
//     _z = ( * (_z)).value.zv;
//     }
// }(void) __h;
// (void) __key;
// (void) _idx;
// if (__builtin_expect(!!(zval_get_type( & ( * (_z))) == 0), 0)) continue;;
// func_name = __key;
// zv = _z;
// {
//     if (func_name) {
//     std::cout << "Function: " << (func_name) -> val << std::endl;
//     }
// }
// }