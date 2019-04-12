module hashed.container;

interface Container(K) {
    V fetch(V)(K key, V alternative);
    V get(V)(K key);
    bool includes(K key) const;
    @property K[] keys() const;
    @property ulong length() const;
    void set(V)(K key, V value);
}
