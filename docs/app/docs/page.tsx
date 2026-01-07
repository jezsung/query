'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';

export default function DocsIndex() {
  const router = useRouter();

  useEffect(() => {
    router.replace('/docs/overview');
  }, [router]);

  return null;
}
