import Image from 'next/image';
import type { BaseLayoutProps } from 'fumadocs-ui/layouts/shared';

export function baseOptions(): BaseLayoutProps {
  return {
    nav: {
      title: <Logo />,
      url: '/docs/overview',
      transparentMode: 'always',
    },
    githubUrl: 'https://github.com/jezsung/query',
  };
}

function Logo() {
  return (
    <span className='flex items-center gap-3'>
      <Image src='/logo.svg' alt='Flutter Query' width={20} height={20} />
      <p className='font-medium'>Flutter Query</p>
    </span>
  );
}
